import Foundation

struct TencentCloudSigner {
    static func headers(
        host: String,
        service: String,
        action: String,
        version: String,
        payload: Data,
        secretID: String,
        secretKey: String,
        date: Date
    ) -> [String: String] {
        let contentType = "application/json; charset=utf-8"
        let timestamp = String(Int(date.timeIntervalSince1970))
        let day = SignatureSupport.utcDate(date, format: "yyyy-MM-dd")
        let signedHeaders = "content-type;host"
        let canonicalHeaders = "content-type:\(contentType)\nhost:\(host)\n"
        let canonicalRequest = [
            "POST",
            "/",
            "",
            canonicalHeaders,
            signedHeaders,
            SignatureSupport.sha256Hex(payload)
        ].joined(separator: "\n")

        let algorithm = "TC3-HMAC-SHA256"
        let credentialScope = "\(day)/\(service)/tc3_request"
        let stringToSign = [
            algorithm,
            timestamp,
            credentialScope,
            SignatureSupport.sha256Hex(Data(canonicalRequest.utf8))
        ].joined(separator: "\n")

        let secretDate = SignatureSupport.hmacSHA256(
            key: Data("TC3\(secretKey)".utf8),
            message: Data(day.utf8)
        )
        let secretService = SignatureSupport.hmacSHA256(
            key: secretDate,
            message: Data(service.utf8)
        )
        let secretSigning = SignatureSupport.hmacSHA256(
            key: secretService,
            message: Data("tc3_request".utf8)
        )
        let signature = SignatureSupport.hmacSHA256(
            key: secretSigning,
            message: Data(stringToSign.utf8)
        ).lowercaseHexString

        let authorization = "\(algorithm) Credential=\(secretID)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        return [
            "Authorization": authorization,
            "Content-Type": contentType,
            "Host": host,
            "X-TC-Action": action,
            "X-TC-Timestamp": timestamp,
            "X-TC-Version": version
        ]
    }
}

actor TencentCloudDNSProvider: DNSProvider {
    nonisolated let kind = DNSProviderKind.dnspod
    nonisolated let capabilities = DNSProviderCapabilities(
        supportedRecordTypes: Set(DNSRecordType.allCases),
        supportsLine: true,
        supportsWeight: true,
        supportsDisableRecord: true,
        ttlRange: 1...604_800
    )

    private let credential: DNSProviderCredential
    private let session: URLSession
    private let host = "dnspod.tencentcloudapi.com"
    private let service = "dnspod"
    private let version = "2021-03-23"

    init(credential: DNSProviderCredential, session: URLSession = .shared) {
        self.credential = credential
        self.session = session
    }

    func testConnection() async throws -> Int {
        let response: DomainListResponse = try await request(
            action: "DescribeDomainList",
            parameters: ["Type": "ALL", "Offset": 0, "Limit": 1]
        )
        return response.domainCountInfo?.allTotal ?? response.domainList.count
    }

    func listDomains() async throws -> [ProviderDomain] {
        var offset = 0
        let limit = 3_000
        var result: [ProviderDomain] = []

        while true {
            let response: DomainListResponse = try await request(
                action: "DescribeDomainList",
                parameters: ["Type": "ALL", "Offset": offset, "Limit": limit]
            )
            result.append(contentsOf: response.domainList.map {
                ProviderDomain(
                    id: String($0.domainID),
                    name: $0.name,
                    recordCount: $0.recordCount,
                    expiresAt: nil
                )
            })
            guard response.domainList.count == limit else { break }
            offset += limit
        }
        return result
    }

    func listRecords(domain: String) async throws -> [ProviderDNSRecord] {
        let response: RecordListResponse = try await request(
            action: "DescribeRecordList",
            parameters: ["Domain": domain, "Offset": 0, "Limit": 3_000]
        )
        return response.recordList.compactMap { item in
            guard let type = DNSRecordType(rawValue: item.type.uppercased()) else { return nil }
            return ProviderDNSRecord(
                id: String(item.recordID),
                name: item.name,
                type: type,
                value: item.value,
                ttl: item.ttl,
                line: item.line,
                priority: item.mx,
                weight: item.weight,
                isEnabled: item.status.uppercased() == "ENABLE"
            )
        }
    }

    func createRecord(domain: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord {
        try DNSRecordValidator.validate(draft, capabilities: capabilities)
        let parameters = recordParameters(domain: domain, draft: draft)
        let response: RecordMutationResponse = try await request(action: "CreateRecord", parameters: parameters)
        return ProviderDNSRecord(
            id: String(response.recordID),
            name: draft.name,
            type: draft.type,
            value: draft.value,
            ttl: draft.ttl,
            line: draft.line ?? "默认",
            priority: draft.priority,
            weight: draft.weight,
            isEnabled: draft.isEnabled
        )
    }

    func updateRecord(domain: String, recordID: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord {
        try DNSRecordValidator.validate(draft, capabilities: capabilities)
        guard let numericRecordID = Int(recordID) else { throw DNSProviderError.recordNotFound }
        var parameters = recordParameters(domain: domain, draft: draft)
        parameters["RecordId"] = numericRecordID
        let response: RecordMutationResponse = try await request(action: "ModifyRecord", parameters: parameters)
        return ProviderDNSRecord(
            id: String(response.recordID),
            name: draft.name,
            type: draft.type,
            value: draft.value,
            ttl: draft.ttl,
            line: draft.line ?? "默认",
            priority: draft.priority,
            weight: draft.weight,
            isEnabled: draft.isEnabled
        )
    }

    func deleteRecord(domain: String, recordID: String) async throws {
        guard let numericRecordID = Int(recordID) else { throw DNSProviderError.recordNotFound }
        let _: EmptyResponse = try await request(
            action: "DeleteRecord",
            parameters: ["Domain": domain, "RecordId": numericRecordID]
        )
    }

    private func recordParameters(domain: String, draft: DNSRecordDraft) -> [String: Any] {
        var parameters: [String: Any] = [
            "Domain": domain,
            "SubDomain": draft.name,
            "RecordType": draft.type.rawValue,
            "RecordLine": draft.line ?? "默认",
            "Value": draft.value,
            "TTL": draft.ttl,
            "Status": draft.isEnabled ? "ENABLE" : "DISABLE"
        ]
        if let priority = draft.priority { parameters["MX"] = priority }
        if let weight = draft.weight { parameters["Weight"] = weight }
        return parameters
    }

    private func request<Response: Decodable>(
        action: String,
        parameters: [String: Any]
    ) async throws -> Response {
        let payload: Data
        do {
            payload = try JSONSerialization.data(withJSONObject: parameters, options: [.sortedKeys])
        } catch {
            throw DNSProviderError.provider("请求参数编码失败")
        }

        guard let url = URL(string: "https://\(host)") else {
            throw DNSProviderError.network("服务地址无效")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        let headers = TencentCloudSigner.headers(
            host: host,
            service: service,
            action: action,
            version: version,
            payload: payload,
            secretID: credential.accessKeyID,
            secretKey: credential.accessKeySecret,
            date: .now
        )
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DNSProviderError.network(error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DNSProviderError.network("服务商未返回 HTTP 响应")
        }

        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let responseObject = root?["Response"] as? [String: Any]
        if let errorObject = responseObject?["Error"] as? [String: Any] {
            throw mapError(
                code: errorObject["Code"] as? String ?? "",
                message: errorObject["Message"] as? String ?? "请求失败"
            )
        }
        guard (200..<300).contains(httpResponse.statusCode), let responseObject else {
            throw DNSProviderError.provider("HTTP \(httpResponse.statusCode)")
        }

        do {
            let responseData = try JSONSerialization.data(withJSONObject: responseObject)
            return try JSONDecoder().decode(Response.self, from: responseData)
        } catch {
            throw DNSProviderError.provider("响应格式无法识别")
        }
    }

    private func mapError(code: String, message: String) -> DNSProviderError {
        let normalized = code.lowercased()
        if normalized.contains("auth") || normalized.contains("secret") || normalized.contains("signature") {
            return .authenticationFailed
        }
        if normalized.contains("permission") || normalized.contains("unauthorized") { return .permissionDenied }
        if normalized.contains("domainnotexist") { return .domainNotFound }
        if normalized.contains("recordnotexist") { return .recordNotFound }
        if normalized.contains("limit") || normalized.contains("requestlimit") { return .rateLimited }
        if normalized.contains("invalidparameter") { return .invalidRecord(message) }
        return .provider(message)
    }
}

private struct DomainListResponse: Decodable {
    let domainCountInfo: DomainCountInfo?
    let domainList: [DomainItem]

    enum CodingKeys: String, CodingKey {
        case domainCountInfo = "DomainCountInfo"
        case domainList = "DomainList"
    }
}

private struct DomainCountInfo: Decodable {
    let allTotal: Int?

    enum CodingKeys: String, CodingKey { case allTotal = "AllTotal" }
}

private struct DomainItem: Decodable {
    let domainID: Int
    let name: String
    let recordCount: Int?

    enum CodingKeys: String, CodingKey {
        case domainID = "DomainId"
        case name = "Name"
        case recordCount = "RecordCount"
    }
}

private struct RecordListResponse: Decodable {
    let recordList: [RecordItem]
    enum CodingKeys: String, CodingKey { case recordList = "RecordList" }
}

private struct RecordItem: Decodable {
    let recordID: Int
    let name: String
    let type: String
    let value: String
    let ttl: Int
    let line: String?
    let mx: Int?
    let weight: Int?
    let status: String

    enum CodingKeys: String, CodingKey {
        case recordID = "RecordId"
        case name = "Name"
        case type = "Type"
        case value = "Value"
        case ttl = "TTL"
        case line = "Line"
        case mx = "MX"
        case weight = "Weight"
        case status = "Status"
    }
}

private struct RecordMutationResponse: Decodable {
    let recordID: Int
    enum CodingKeys: String, CodingKey { case recordID = "RecordId" }
}

private struct EmptyResponse: Decodable {}
