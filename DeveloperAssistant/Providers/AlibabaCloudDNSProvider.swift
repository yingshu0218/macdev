import Foundation

struct AlibabaCloudSigner {
    static func signedRequest(
        host: String,
        action: String,
        version: String,
        query: [String: String],
        accessKeyID: String,
        accessKeySecret: String,
        date: Date,
        nonce: String
    ) -> URLRequest {
        let payload = Data()
        let payloadHash = SignatureSupport.sha256Hex(payload)
        let dateString = SignatureSupport.utcDate(date, format: "yyyy-MM-dd'T'HH:mm:ss'Z'")
        let sortedQuery = query
            .sorted { $0.key < $1.key }
            .map { "\(SignatureSupport.rfc3986Encode($0.key))=\(SignatureSupport.rfc3986Encode($0.value))" }
            .joined(separator: "&")
        let signedHeaders = "host;x-acs-action;x-acs-content-sha256;x-acs-date;x-acs-signature-nonce;x-acs-version"
        let canonicalHeaders = [
            "host:\(host)",
            "x-acs-action:\(action)",
            "x-acs-content-sha256:\(payloadHash)",
            "x-acs-date:\(dateString)",
            "x-acs-signature-nonce:\(nonce)",
            "x-acs-version:\(version)"
        ].joined(separator: "\n") + "\n"
        let canonicalRequest = [
            "POST",
            "/",
            sortedQuery,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")
        let algorithm = "ACS3-HMAC-SHA256"
        let stringToSign = "\(algorithm)\n\(SignatureSupport.sha256Hex(Data(canonicalRequest.utf8)))"
        let signature = SignatureSupport.hmacSHA256(
            key: Data(accessKeySecret.utf8),
            message: Data(stringToSign.utf8)
        ).lowercaseHexString
        let authorization = "\(algorithm) Credential=\(accessKeyID),SignedHeaders=\(signedHeaders),Signature=\(signature)"

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/"
        components.percentEncodedQuery = sortedQuery
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(action, forHTTPHeaderField: "x-acs-action")
        request.setValue(payloadHash, forHTTPHeaderField: "x-acs-content-sha256")
        request.setValue(dateString, forHTTPHeaderField: "x-acs-date")
        request.setValue(nonce, forHTTPHeaderField: "x-acs-signature-nonce")
        request.setValue(version, forHTTPHeaderField: "x-acs-version")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

actor AlibabaCloudDNSProvider: DNSProvider {
    nonisolated let kind = DNSProviderKind.alidns
    nonisolated let capabilities = DNSProviderCapabilities(
        supportedRecordTypes: Set(DNSRecordType.allCases),
        supportsLine: true,
        supportsWeight: true,
        supportsDisableRecord: true,
        ttlRange: 1...86_400
    )

    private let credential: DNSProviderCredential
    private let session: URLSession
    private let host = "alidns.cn-hangzhou.aliyuncs.com"
    private let version = "2015-01-09"

    init(credential: DNSProviderCredential, session: URLSession = .shared) {
        self.credential = credential
        self.session = session
    }

    func testConnection() async throws -> Int {
        let response: AliDomainListResponse = try await request(
            action: "DescribeDomains",
            query: ["PageNumber": "1", "PageSize": "1"]
        )
        return response.totalCount
    }

    func listDomains() async throws -> [ProviderDomain] {
        var page = 1
        let pageSize = 100
        var result: [ProviderDomain] = []

        while true {
            let response: AliDomainListResponse = try await request(
                action: "DescribeDomains",
                query: ["PageNumber": String(page), "PageSize": String(pageSize)]
            )
            result.append(contentsOf: response.domains.domain.map {
                ProviderDomain(
                    id: $0.domainID,
                    name: $0.domainName.trimmingCharacters(in: .whitespacesAndNewlines),
                    recordCount: $0.recordCount,
                    expiresAt: $0.instanceEndTime.flatMap(Self.parseDate)
                )
            })
            guard result.count < response.totalCount else { break }
            page += 1
        }
        return result
    }

    func listRecords(domain: String) async throws -> [ProviderDNSRecord] {
        var page = 1
        let pageSize = 500
        var result: [ProviderDNSRecord] = []

        while true {
            let response: AliRecordListResponse = try await request(
                action: "DescribeDomainRecords",
                query: [
                    "DomainName": domain,
                    "PageNumber": String(page),
                    "PageSize": String(pageSize)
                ]
            )
            result.append(contentsOf: response.domainRecords.record.compactMap { item in
                guard let type = DNSRecordType(rawValue: item.type.uppercased()) else { return nil }
                return ProviderDNSRecord(
                    id: item.recordID,
                    name: item.rr,
                    type: type,
                    value: item.value,
                    ttl: item.ttl,
                    line: item.line,
                    priority: item.priority,
                    weight: item.weight,
                    isEnabled: item.status.caseInsensitiveCompare("Enable") == .orderedSame
                )
            })
            guard result.count < response.totalCount else { break }
            page += 1
        }
        return result
    }

    func createRecord(domain: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord {
        try DNSRecordValidator.validate(draft, capabilities: capabilities)
        let response: AliRecordMutationResponse = try await request(
            action: "AddDomainRecord",
            query: recordQuery(domain: domain, draft: draft)
        )
        if !draft.isEnabled {
            try await setStatus(recordID: response.recordID, isEnabled: false)
        }
        return makeRecord(id: response.recordID, draft: draft)
    }

    func updateRecord(domain: String, recordID: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord {
        try DNSRecordValidator.validate(draft, capabilities: capabilities)
        var query = recordQuery(domain: nil, draft: draft)
        query["RecordId"] = recordID
        let _: AliRecordMutationResponse = try await request(action: "UpdateDomainRecord", query: query)
        try await setStatus(recordID: recordID, isEnabled: draft.isEnabled)
        return makeRecord(id: recordID, draft: draft)
    }

    func deleteRecord(domain: String, recordID: String) async throws {
        let _: AliEmptyResponse = try await request(
            action: "DeleteDomainRecord",
            query: ["RecordId": recordID]
        )
    }

    private func setStatus(recordID: String, isEnabled: Bool) async throws {
        let _: AliRecordMutationResponse = try await request(
            action: "SetDomainRecordStatus",
            query: ["RecordId": recordID, "Status": isEnabled ? "Enable" : "Disable"]
        )
    }

    private func recordQuery(domain: String?, draft: DNSRecordDraft) -> [String: String] {
        var query: [String: String] = [
            "RR": draft.name,
            "Type": draft.type.rawValue,
            "Value": draft.value,
            "TTL": String(draft.ttl),
            "Line": draft.line ?? "default"
        ]
        if let domain { query["DomainName"] = domain }
        if let priority = draft.priority { query["Priority"] = String(priority) }
        if let weight = draft.weight { query["Weight"] = String(weight) }
        return query
    }

    private func makeRecord(id: String, draft: DNSRecordDraft) -> ProviderDNSRecord {
        ProviderDNSRecord(
            id: id,
            name: draft.name,
            type: draft.type,
            value: draft.value,
            ttl: draft.ttl,
            line: draft.line ?? "default",
            priority: draft.priority,
            weight: draft.weight,
            isEnabled: draft.isEnabled
        )
    }

    private func request<Response: Decodable>(
        action: String,
        query: [String: String]
    ) async throws -> Response {
        let request = AlibabaCloudSigner.signedRequest(
            host: host,
            action: action,
            version: version,
            query: query,
            accessKeyID: credential.accessKeyID,
            accessKeySecret: credential.accessKeySecret,
            date: .now,
            nonce: UUID().uuidString.lowercased()
        )

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

        if let errorResponse = try? JSONDecoder().decode(AliErrorResponse.self, from: data), errorResponse.code != nil {
            throw mapError(code: errorResponse.code ?? "", message: errorResponse.message ?? "请求失败")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DNSProviderError.provider("HTTP \(httpResponse.statusCode)")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw DNSProviderError.provider("响应格式无法识别")
        }
    }

    private func mapError(code: String, message: String) -> DNSProviderError {
        let normalized = code.lowercased()
        if normalized.contains("signature") || normalized.contains("accesskey") || normalized.contains("forbidden") {
            return .authenticationFailed
        }
        if normalized.contains("permission") || normalized.contains("denied") { return .permissionDenied }
        if normalized.contains("domainnotexist") { return .domainNotFound }
        if normalized.contains("recordnotexist") { return .recordNotFound }
        if normalized.contains("throttling") || normalized.contains("quota") { return .rateLimited }
        if normalized.contains("invalid") { return .invalidRecord(message) }
        return .provider(message)
    }

    private static func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}

private struct AliDomainListResponse: Decodable {
    let domains: AliDomains
    let totalCount: Int
    enum CodingKeys: String, CodingKey {
        case domains = "Domains"
        case totalCount = "TotalCount"
    }
}

private struct AliDomains: Decodable {
    let domain: [AliDomainItem]
    enum CodingKeys: String, CodingKey { case domain = "Domain" }
}

private struct AliDomainItem: Decodable {
    let domainID: String
    let domainName: String
    let recordCount: Int?
    let instanceEndTime: String?
    enum CodingKeys: String, CodingKey {
        case domainID = "DomainId"
        case domainName = "DomainName"
        case recordCount = "RecordCount"
        case instanceEndTime = "InstanceEndTime"
    }
}

private struct AliRecordListResponse: Decodable {
    let totalCount: Int
    let domainRecords: AliDomainRecords
    enum CodingKeys: String, CodingKey {
        case totalCount = "TotalCount"
        case domainRecords = "DomainRecords"
    }
}

private struct AliDomainRecords: Decodable {
    let record: [AliRecordItem]
    enum CodingKeys: String, CodingKey { case record = "Record" }
}

private struct AliRecordItem: Decodable {
    let recordID: String
    let rr: String
    let type: String
    let value: String
    let ttl: Int
    let line: String?
    let priority: Int?
    let weight: Int?
    let status: String
    enum CodingKeys: String, CodingKey {
        case recordID = "RecordId"
        case rr = "RR"
        case type = "Type"
        case value = "Value"
        case ttl = "TTL"
        case line = "Line"
        case priority = "Priority"
        case weight = "Weight"
        case status = "Status"
    }
}

private struct AliRecordMutationResponse: Decodable {
    let recordID: String
    enum CodingKeys: String, CodingKey { case recordID = "RecordId" }
}

private struct AliEmptyResponse: Decodable {}

private struct AliErrorResponse: Decodable {
    let code: String?
    let message: String?
    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case message = "Message"
    }
}
