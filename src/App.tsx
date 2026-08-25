import { useMemo, useState } from "react";

type Domain = { name: string; project: string; provider: string; records: number; expires: string; status: "正常" | "即将到期" };
type DNSRecord = { id: number; host: string; type: "A" | "CNAME" | "TXT"; value: string; ttl: number };

const domains: Domain[] = [
  { name: "example.com", project: "默认项目", provider: "阿里云 / 主账号", records: 12, expires: "2026-06-15", status: "正常" },
  { name: "api-studio.dev", project: "API 工作室", provider: "腾讯云 / 主账号", records: 8, expires: "2027-02-20", status: "正常" },
  { name: "mylab.cn", project: "个人实验室", provider: "DNSPod / 主账号", records: 5, expires: "2026-09-10", status: "即将到期" }
];

const Icon = ({ name }: { name: "grid" | "folder" | "clock" | "link" | "server" | "settings" | "search" | "sync" | "chevron" }) => {
  const paths: Record<string, React.ReactNode> = {
    grid: <><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></>,
    folder: <path d="M3 6h7l2 2h9v11H3z"/>, clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v6l4 2"/></>,
    link: <><path d="M10 13a5 5 0 0 0 7.5.5l2-2a5 5 0 0 0-7-7l-1.1 1.1"/><path d="M14 11a5 5 0 0 0-7.5-.5l-2 2a5 5 0 0 0 7 7l1.1-1.1"/></>,
    server: <><rect x="3" y="4" width="18" height="6" rx="1"/><rect x="3" y="14" width="18" height="6" rx="1"/><path d="M7 7h.01M7 17h.01"/></>,
    settings: <><circle cx="12" cy="12" r="3"/><path d="M19 13.5v-3l-2-.7-.8-1.8.9-1.9-2.2-2.2-1.9.9-1.8-.8-.7-2h-3l-.7 2-1.8.8-1.9-.9L.9 6.1 1.8 8l-.8 1.8-2 .7v3l2 .7.8 1.8-.9 1.9 2.2 2.2 1.9-.9 1.8.8.7 2h3l.7-2 1.8-.8 1.9.9 2.2-2.2-.9-1.9.8-1.8z" transform="translate(2 0) scale(.83)"/></>,
    search: <><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></>,
    sync: <><path d="M20 7h-6V1"/><path d="M20 7a9 9 0 1 0 1 8"/></>, chevron: <path d="m9 18 6-6-6-6"/>
  };
  return <svg className="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>;
};

type PageId = "workbench" | "projects" | "history" | "connections" | "servers" | "settings";

const nav = [["workbench", "工作台", "grid"], ["projects", "项目与标签", "folder"], ["history", "操作历史", "clock"], ["connections", "服务商连接", "link"]] as const;
const pageTitles: Record<PageId, [string, string]> = {
  workbench: ["DNS 工作台", "统一查看和维护所有域名"], projects: ["项目与标签", "按业务组织域名和开发资源"], history: ["操作历史", "查看同步、修改和删除操作"],
  connections: ["服务商连接", "统一管理 DNS 服务商账号"], servers: ["服务器管理", "查看服务器资产与在线状态"], settings: ["系统设置", "管理桌面应用和安全选项"]
};
const moduleRows: Record<Exclude<PageId, "workbench">, string[][]> = {
  projects: [["默认项目", "3 个域名", "刚刚更新"], ["API 工作室", "1 个域名", "2 小时前"], ["个人实验室", "1 个域名", "昨天"]],
  history: [["同步域名", "成功", "刚刚"], ["更新解析 example.com", "成功", "18 分钟前"], ["测试 DNSPod 连接", "成功", "昨天"]],
  connections: [["阿里云", "主账号", "已连接"], ["腾讯云", "主账号", "已连接"], ["DNSPod", "主账号", "已连接"]],
  servers: [["production-01", "47.100.10.8", "在线"], ["staging-01", "43.138.22.16", "在线"], ["backup-node", "10.0.0.12", "离线"]],
  settings: [["桌面模式", "数据保存在本机", "已启用"], ["自动检查更新", "启动时检查新版本", "已启用"], ["应用锁", "离开时保护敏感数据", "未启用"]]
};

function ModulePage({ page, onAction }: { page: Exclude<PageId, "workbench">; onAction: (message: string) => void }) {
  const headings: Record<typeof page, string[]> = { projects: ["名称", "资源", "最近更新"], history: ["操作", "结果", "时间"], connections: ["服务商", "账号", "状态"], servers: ["服务器", "地址", "状态"], settings: ["设置项", "说明", "当前状态"] };
  const primaryLabel = page === "settings" ? "保存设置" : page === "history" ? "导出记录" : "添加";
  return <section className="module-page"><div className="module-head"><div><h2>{pageTitles[page][0]}</h2><p>{pageTitles[page][1]}</p></div><button className="primary" onClick={() => onAction(`${primaryLabel}操作已响应`)}>{primaryLabel}</button></div>
    <div className="module-table"><div className="module-row module-labels">{headings[page].map((item) => <span key={item}>{item}</span>)}</div>{moduleRows[page].map((row) => <button className="module-row" key={row[0]} onClick={() => onAction(`已打开：${row[0]}`)}>{row.map((item, index) => <span key={item} className={index === 2 ? "row-status" : ""}>{item}</span>)}<Icon name="chevron"/></button>)}</div></section>;
}

function App() {
  const [activePage, setActivePage] = useState<PageId>("workbench");
  const [dnsOpen, setDnsOpen] = useState(true);
  const [notice, setNotice] = useState("");
  const [query, setQuery] = useState("");
  const [projectFilter, setProjectFilter] = useState("全部项目");
  const [providerFilter, setProviderFilter] = useState("全部服务商");
  const [statusFilter, setStatusFilter] = useState("全部状态");
  const [syncing, setSyncing] = useState(false);
  const [synced, setSynced] = useState(false);
  const [selected, setSelected] = useState<Domain | null>(null);
  const [drawerMode, setDrawerMode] = useState<"details" | "records">("details");
  const [recordFormOpen, setRecordFormOpen] = useState(false);
  const [editingRecord, setEditingRecord] = useState<DNSRecord | null>(null);
  const [recordDraft, setRecordDraft] = useState({ host: "@", type: "A" as DNSRecord["type"], value: "", ttl: 600 });
  const [records, setRecords] = useState<Record<string, DNSRecord[]>>({
    "example.com": [{ id: 1, host: "@", type: "A", value: "47.100.10.8", ttl: 600 }, { id: 2, host: "www", type: "CNAME", value: "example.com", ttl: 600 }],
    "api-studio.dev": [{ id: 3, host: "api", type: "A", value: "43.138.22.16", ttl: 300 }],
    "mylab.cn": [{ id: 4, host: "@", type: "TXT", value: "site-verification=demo", ttl: 600 }]
  });
  const filtered = useMemo(() => domains.filter((d) => `${d.name}${d.project}${d.provider}`.toLowerCase().includes(query.toLowerCase())
    && (projectFilter === "全部项目" || d.project === projectFilter)
    && (providerFilter === "全部服务商" || d.provider.startsWith(providerFilter))
    && (statusFilter === "全部状态" || d.status === statusFilter)), [query, projectFilter, providerFilter, statusFilter]);
  const cycle = (current: string, options: string[], update: (value: string) => void) => update(options[(options.indexOf(current) + 1) % options.length]);

  const sync = () => {
    setSyncing(true); setSynced(false);
    window.setTimeout(() => { setSyncing(false); setSynced(true); }, 900);
  };
  const navigate = (page: PageId) => { setActivePage(page); setSelected(null); setDrawerMode("details"); setSynced(false); setSyncing(false); };
  const openDomain = (domain: Domain) => { setSelected(domain); setDrawerMode("details"); };
  const openRecordForm = (record?: DNSRecord) => {
    setEditingRecord(record ?? null);
    setRecordDraft(record ? { host: record.host, type: record.type, value: record.value, ttl: record.ttl } : { host: "@", type: "A", value: "", ttl: 600 });
    setRecordFormOpen(true);
  };
  const saveRecord = () => {
    if (!selected || !recordDraft.host.trim() || !recordDraft.value.trim()) return;
    setRecords((current) => {
      const list = current[selected.name] ?? [];
      const next = editingRecord ? list.map((item) => item.id === editingRecord.id ? { ...recordDraft, id: item.id } : item) : [...list, { ...recordDraft, id: Date.now() }];
      return { ...current, [selected.name]: next };
    });
    setRecordFormOpen(false); setEditingRecord(null);
  };
  const deleteRecord = (id: number) => selected && setRecords((current) => ({ ...current, [selected.name]: (current[selected.name] ?? []).filter((record) => record.id !== id) }));

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">&lt;/&gt;</span><span>开发管理助手</span></div>
      <div className="nav-section"><button className="section-title section-toggle" onClick={() => setDnsOpen((open) => !open)} aria-expanded={dnsOpen}><span>DNS 管理</span><span>{dnsOpen ? "⌃" : "⌄"}</span></button>
        {dnsOpen ? nav.map(([id, label, icon]) => <button key={id} onClick={() => navigate(id)} aria-current={activePage === id ? "page" : undefined} className={`nav-item ${activePage === id ? "active" : ""}`}><Icon name={icon}/><span>{label}</span></button>) : null}
      </div>
      <div className="nav-divider" />
      <button onClick={() => navigate("servers")} className={`nav-item ${activePage === "servers" ? "active" : ""}`}><Icon name="server"/><span>服务器管理</span><span className="nav-tail">›</span></button>
      <button onClick={() => navigate("settings")} className={`nav-item ${activePage === "settings" ? "active" : ""}`}><Icon name="settings"/><span>系统设置</span><span className="nav-tail">›</span></button>
      <div className="sidebar-foot"><span className="status-dot"/> 本地桌面模式 <span className="version">v0.1</span></div>
    </aside>

    <main className="main">
      <header className="topbar"><div><h1>{pageTitles[activePage][0]}</h1><p>{pageTitles[activePage][1]}</p></div>
        <label className="global-search"><Icon name="search"/><input aria-label="全局搜索" value={query} onFocus={() => navigate("workbench")} onChange={(event) => setQuery(event.target.value)} placeholder="搜索域名、记录值或 IP" /></label>
        <div className="connection"><span className="status-dot"/> 连接正常</div>
      </header>
      <div className="content">{activePage === "workbench" ? <>
        <section className="metrics" aria-label="资源概览">
          <div><span>域名总数</span><strong>3</strong></div><div><span>解析记录总数</span><strong>25</strong></div><div><span>即将到期</span><strong className="warning">1</strong></div><div><span>异常域名</span><strong>0</strong></div>
        </section>
        <section className="workspace">
          <div className="toolbar">
            <button className="primary" onClick={sync}><Icon name="sync"/>同步域名</button>
            <label className="filter-search"><Icon name="search"/><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="筛选当前域名" /></label>
            <button className="select-btn" onClick={() => cycle(projectFilter, ["全部项目", "默认项目", "API 工作室", "个人实验室"], setProjectFilter)}>{projectFilter} <span>⌄</span></button>
            <button className="select-btn" onClick={() => cycle(providerFilter, ["全部服务商", "阿里云", "腾讯云", "DNSPod"], setProviderFilter)}>{providerFilter} <span>⌄</span></button>
            <button className="select-btn" onClick={() => cycle(statusFilter, ["全部状态", "正常", "即将到期"], setStatusFilter)}>{statusFilter} <span>⌄</span></button>
          </div>
          <div className="table-wrap"><table><thead><tr><th>域名</th><th>项目</th><th>服务商 / 账号</th><th>解析</th><th>到期时间</th><th>状态</th><th/></tr></thead>
            <tbody>{filtered.map((d) => <tr key={d.name} onClick={() => openDomain(d)}><td className="domain">{d.name}</td><td>{d.project}</td><td>{d.provider}</td><td>{records[d.name]?.length ?? 0}</td><td className={d.status === "即将到期" ? "warning" : ""}>{d.expires}</td><td><span className={`state ${d.status === "正常" ? "ok" : "warn"}`}><i/>{d.status}</span></td><td><Icon name="chevron"/></td></tr>)}</tbody></table>
            {filtered.length === 0 && <div className="empty">没有找到匹配的域名</div>}
          </div>
          <div className="table-foot"><span>共 {filtered.length} 条</span><span>数据仅用于桌面版效果演示</span></div>
        </section></> : <ModulePage page={activePage} onAction={setNotice} />}
      </div>
    </main>

    {(syncing || synced) && <div className="overlay" role="dialog" aria-modal="true"><div className="dialog">
      <button className="close" onClick={() => { setSyncing(false); setSynced(false); }}>×</button>
      <div className={`result-icon ${synced ? "success" : "loading"}`}>{synced ? "✓" : "↻"}</div>
      <h2>{synced ? "同步成功" : "同步域名中…"}</h2><p>{synced ? "已成功同步 3 个域名，25 条解析记录" : "正在从 3 个服务商连接获取最新数据"}</p>
      {syncing && <div className="progress"><span/></div>}{synced && <button className="primary confirm" onClick={() => setSynced(false)}>确定</button>}
    </div></div>}
    {notice && <div className="overlay" role="dialog" aria-modal="true"><div className="dialog"><button className="close" onClick={() => setNotice("")}>×</button><div className="result-icon success">✓</div><h2>操作已响应</h2><p>{notice}</p><button className="primary confirm" onClick={() => setNotice("")}>确定</button></div></div>}

    {selected && <><div className="drawer-mask" onClick={() => setSelected(null)}/><aside className="drawer record-drawer"><button className="close" onClick={() => setSelected(null)}>×</button>
      {drawerMode === "details" ? <><p className="eyeline">域名详情</p><h2>{selected.name}</h2><div className="detail-grid"><span>项目</span><strong>{selected.project}</strong><span>服务商</span><strong>{selected.provider}</strong><span>解析记录</span><strong>{records[selected.name]?.length ?? 0} 条</strong><span>到期时间</span><strong>{selected.expires}</strong></div><button className="primary drawer-action" onClick={() => setDrawerMode("records")}>管理解析记录</button></> : <>
        <button className="back-button" onClick={() => setDrawerMode("details")}>← 返回域名详情</button><div className="records-title"><div><p className="eyeline">解析记录</p><h2>{selected.name}</h2></div><button className="primary" onClick={() => openRecordForm()}>新增解析</button></div>
        <div className="records-list"><div className="record-row record-head"><span>主机</span><span>类型</span><span>记录值</span><span>TTL</span><span>操作</span></div>{(records[selected.name] ?? []).map((record) => <div className="record-row" key={record.id}><strong>{record.host}</strong><span className="record-type">{record.type}</span><span className="record-value">{record.value}</span><span>{record.ttl}</span><span className="record-actions"><button onClick={() => openRecordForm(record)}>编辑</button><button className="danger-link" onClick={() => deleteRecord(record.id)}>删除</button></span></div>)}</div>
        {(records[selected.name] ?? []).length === 0 ? <div className="empty records-empty">暂无解析记录</div> : null}
      </>}
    </aside></>}
    {recordFormOpen && selected && <div className="overlay record-overlay" role="dialog" aria-modal="true"><div className="dialog record-dialog"><button className="close" onClick={() => setRecordFormOpen(false)}>×</button><h2>{editingRecord ? "编辑解析记录" : "新增解析记录"}</h2><div className="record-form"><label>主机记录<input value={recordDraft.host} onChange={(event) => setRecordDraft({ ...recordDraft, host: event.target.value })}/></label><label>记录类型<select value={recordDraft.type} onChange={(event) => setRecordDraft({ ...recordDraft, type: event.target.value as DNSRecord["type"] })}><option>A</option><option>CNAME</option><option>TXT</option></select></label><label>记录值<input value={recordDraft.value} onChange={(event) => setRecordDraft({ ...recordDraft, value: event.target.value })} placeholder="请输入 IP、域名或文本"/></label><label>TTL<input type="number" value={recordDraft.ttl} onChange={(event) => setRecordDraft({ ...recordDraft, ttl: Number(event.target.value) })}/></label></div><div className="dialog-actions"><button className="select-btn" onClick={() => setRecordFormOpen(false)}>取消</button><button className="primary" disabled={!recordDraft.host.trim() || !recordDraft.value.trim()} onClick={saveRecord}>保存</button></div></div></div>}
  </div>;
}

export default App;
