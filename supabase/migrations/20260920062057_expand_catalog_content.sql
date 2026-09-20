-- Expand catalog: roles, skills, resources, scenario questions

insert into public.roles (id, slug, title, description) values
  ('11111111-1111-1111-1111-111111111004', 'ml-engineer', 'Machine Learning Engineer', 'Build and ship ML systems with Python, data, and model fundamentals.'),
  ('11111111-1111-1111-1111-111111111005', 'cybersecurity-analyst', 'Cybersecurity Analyst', 'Defend systems with networking, Linux, and threat awareness.'),
  ('11111111-1111-1111-1111-111111111006', 'fullstack-dev', 'Full-Stack Developer', 'Ship end-to-end features across UI, APIs, and data.')
on conflict (id) do nothing;

insert into public.skills (id, slug, name, category, prerequisites) values
  ('22222222-2222-2222-2222-222222220011', 'pandas-numpy', 'Pandas & NumPy', 'data', array['22222222-2222-2222-2222-222222220001'::uuid]),
  ('22222222-2222-2222-2222-222222220012', 'ml-fundamentals', 'ML Fundamentals', 'ml', array['22222222-2222-2222-2222-222222220011'::uuid,'22222222-2222-2222-2222-222222220003'::uuid]),
  ('22222222-2222-2222-2222-222222220013', 'git-collab', 'Git & Collaboration', 'tools', '{}'),
  ('22222222-2222-2222-2222-222222220014', 'networking-basics', 'Networking Basics', 'security', '{}'),
  ('22222222-2222-2222-2222-222222220015', 'linux-fundamentals', 'Linux Fundamentals', 'security', '{}'),
  ('22222222-2222-2222-2222-222222220016', 'threat-basics', 'Threat Basics', 'security', array['22222222-2222-2222-2222-222222220014'::uuid]),
  ('22222222-2222-2222-2222-222222220017', 'typescript', 'TypeScript', 'web', array['22222222-2222-2222-2222-222222220006'::uuid]),
  ('22222222-2222-2222-2222-222222220018', 'nodejs', 'Node.js', 'backend', array['22222222-2222-2222-2222-222222220006'::uuid]),
  ('22222222-2222-2222-2222-222222220019', 'system-design-basics', 'System Design Basics', 'architecture', array['22222222-2222-2222-2222-222222220008'::uuid,'22222222-2222-2222-2222-222222220009'::uuid])
on conflict (id) do nothing;

insert into public.role_skills (role_id, skill_id, required_level, importance) values
  -- ML Engineer
  ('11111111-1111-1111-1111-111111111004', '22222222-2222-2222-2222-222222220001', 8, 5),
  ('11111111-1111-1111-1111-111111111004', '22222222-2222-2222-2222-222222220011', 9, 5),
  ('11111111-1111-1111-1111-111111111004', '22222222-2222-2222-2222-222222220003', 8, 4),
  ('11111111-1111-1111-1111-111111111004', '22222222-2222-2222-2222-222222220012', 9, 5),
  ('11111111-1111-1111-1111-111111111004', '22222222-2222-2222-2222-222222220013', 6, 3),
  -- Cybersecurity
  ('11111111-1111-1111-1111-111111111005', '22222222-2222-2222-2222-222222220014', 8, 5),
  ('11111111-1111-1111-1111-111111111005', '22222222-2222-2222-2222-222222220015', 8, 5),
  ('11111111-1111-1111-1111-111111111005', '22222222-2222-2222-2222-222222220016', 9, 5),
  ('11111111-1111-1111-1111-111111111005', '22222222-2222-2222-2222-222222220010', 8, 4),
  ('11111111-1111-1111-1111-111111111005', '22222222-2222-2222-2222-222222220013', 6, 3),
  -- Full-stack
  ('11111111-1111-1111-1111-111111111006', '22222222-2222-2222-2222-222222220007', 8, 5),
  ('11111111-1111-1111-1111-111111111006', '22222222-2222-2222-2222-222222220017', 7, 4),
  ('11111111-1111-1111-1111-111111111006', '22222222-2222-2222-2222-222222220018', 8, 5),
  ('11111111-1111-1111-1111-111111111006', '22222222-2222-2222-2222-222222220008', 8, 4),
  ('11111111-1111-1111-1111-111111111006', '22222222-2222-2222-2222-222222220009', 7, 4),
  ('11111111-1111-1111-1111-111111111006', '22222222-2222-2222-2222-222222220013', 7, 3),
  ('11111111-1111-1111-1111-111111111006', '22222222-2222-2222-2222-222222220019', 6, 3)
on conflict (role_id, skill_id) do nothing;

-- Extra resources for existing + new skills (multi per skill)
insert into public.resources (id, skill_id, title, url, type, difficulty) values
  ('33333333-3333-3333-3333-333333330011', '22222222-2222-2222-2222-222222220001', 'freeCodeCamp Python', 'https://www.freecodecamp.org/learn/scientific-computing-with-python/', 'course', 2),
  ('33333333-3333-3333-3333-333333330012', '22222222-2222-2222-2222-222222220001', 'Real Python Tutorials', 'https://realpython.com/', 'article', 3),
  ('33333333-3333-3333-3333-333333330013', '22222222-2222-2222-2222-222222220002', 'PostgreSQL Official Docs', 'https://www.postgresql.org/docs/current/', 'docs', 3),
  ('33333333-3333-3333-3333-333333330014', '22222222-2222-2222-2222-222222220002', 'Mode SQL Tutorial', 'https://mode.com/sql-tutorial/', 'course', 2),
  ('33333333-3333-3333-3333-333333330015', '22222222-2222-2222-2222-222222220005', 'The Odin Project Foundations', 'https://www.theodinproject.com/paths/foundations', 'course', 2),
  ('33333333-3333-3333-3333-333333330016', '22222222-2222-2222-2222-222222220006', 'Eloquent JavaScript (book)', 'https://eloquentjavascript.net/', 'course', 3),
  ('33333333-3333-3333-3333-333333330017', '22222222-2222-2222-2222-222222220006', 'You Don''t Know JS (repo)', 'https://github.com/getify/You-Dont-Know-JS', 'repo', 4),
  ('33333333-3333-3333-3333-333333330018', '22222222-2222-2222-2222-222222220007', 'React Beta Docs Challenges', 'https://react.dev/learn', 'docs', 3),
  ('33333333-3333-3333-3333-333333330019', '22222222-2222-2222-2222-222222220008', 'HTTP Guide — MDN', 'https://developer.mozilla.org/en-US/docs/Web/HTTP', 'docs', 3),
  ('33333333-3333-3333-3333-333333330020', '22222222-2222-2222-2222-222222220010', 'OWASP Cheatsheet Series', 'https://cheatsheetseries.owasp.org/', 'docs', 4),
  ('33333333-3333-3333-3333-333333330021', '22222222-2222-2222-2222-222222220011', 'NumPy User Guide', 'https://numpy.org/doc/stable/user/', 'docs', 3),
  ('33333333-3333-3333-3333-333333330022', '22222222-2222-2222-2222-222222220011', 'Pandas Getting Started', 'https://pandas.pydata.org/docs/getting_started/', 'docs', 2),
  ('33333333-3333-3333-3333-333333330023', '22222222-2222-2222-2222-222222220011', 'Python Data Science Handbook', 'https://jakevdp.github.io/PythonDataScienceHandbook/', 'course', 4),
  ('33333333-3333-3333-3333-333333330024', '22222222-2222-2222-2222-222222220012', 'Google ML Crash Course', 'https://developers.google.com/machine-learning/crash-course', 'course', 3),
  ('33333333-3333-3333-3333-333333330025', '22222222-2222-2222-2222-222222220012', 'scikit-learn User Guide', 'https://scikit-learn.org/stable/user_guide.html', 'docs', 4),
  ('33333333-3333-3333-3333-333333330026', '22222222-2222-2222-2222-222222220012', 'fast.ai Practical DL', 'https://www.fast.ai/', 'course', 4),
  ('33333333-3333-3333-3333-333333330027', '22222222-2222-2222-2222-222222220013', 'Pro Git Book', 'https://git-scm.com/book/en/v2', 'docs', 3),
  ('33333333-3333-3333-3333-333333330028', '22222222-2222-2222-2222-222222220013', 'GitHub Skills', 'https://skills.github.com/', 'course', 2),
  ('33333333-3333-3333-3333-333333330029', '22222222-2222-2222-2222-222222220013', 'Oh My Git! (OSS game)', 'https://ohmygit.org/', 'course', 2),
  ('33333333-3333-3333-3333-333333330030', '22222222-2222-2222-2222-222222220014', 'Cloudflare Learning — Networking', 'https://www.cloudflare.com/learning/network-layer/what-is-a-computer-network/', 'article', 2),
  ('33333333-3333-3333-3333-333333330031', '22222222-2222-2222-2222-222222220014', 'Beej''s Guide to Network Concepts', 'https://beej.us/guide/bgnet0/', 'docs', 3),
  ('33333333-3333-3333-3333-333333330032', '22222222-2222-2222-2222-222222220015', 'Linux Journey', 'https://linuxjourney.com/', 'course', 2),
  ('33333333-3333-3333-3333-333333330033', '22222222-2222-2222-2222-222222220015', 'The Linux Command Line (book site)', 'https://linuxcommand.org/', 'docs', 3),
  ('33333333-3333-3333-3333-333333330034', '22222222-2222-2222-2222-222222220016', 'MITRE ATT&CK', 'https://attack.mitre.org/', 'docs', 4),
  ('33333333-3333-3333-3333-333333330035', '22222222-2222-2222-2222-222222220016', 'OWASP Top 10', 'https://owasp.org/www-project-top-ten/', 'article', 3),
  ('33333333-3333-3333-3333-333333330036', '22222222-2222-2222-2222-222222220017', 'TypeScript Handbook', 'https://www.typescriptlang.org/docs/handbook/intro.html', 'docs', 3),
  ('33333333-3333-3333-3333-333333330037', '22222222-2222-2222-2222-222222220017', 'Total TypeScript Beginners', 'https://www.totaltypescript.com/tutorials', 'course', 3),
  ('33333333-3333-3333-3333-333333330038', '22222222-2222-2222-2222-222222220018', 'Node.js Docs Guides', 'https://nodejs.org/en/learn', 'docs', 3),
  ('33333333-3333-3333-3333-333333330039', '22222222-2222-2222-2222-222222220018', 'Express.js Guide', 'https://expressjs.com/en/starter/installing.html', 'docs', 3),
  ('33333333-3333-3333-3333-333333330040', '22222222-2222-2222-2222-222222220019', 'System Design Primer (repo)', 'https://github.com/donnemartin/system-design-primer', 'repo', 4),
  ('33333333-3333-3333-3333-333333330041', '22222222-2222-2222-2222-222222220003', 'Seeing Theory', 'https://seeing-theory.brown.edu/', 'course', 3),
  ('33333333-3333-3333-3333-333333330042', '22222222-2222-2222-2222-222222220004', 'Data Viz Catalogue', 'https://datavizcatalogue.com/', 'article', 2),
  ('33333333-3333-3333-3333-333333330043', '22222222-2222-2222-2222-222222220009', 'Use The Index, Luke', 'https://use-the-index-luke.com/', 'article', 4)
on conflict (id) do nothing;

-- Scenario + standard questions for new skills and denser existing skills
insert into public.questions (skill_id, difficulty, stem, options, correct_index, explanation, source, reviewed, concept) values
-- Pandas / NumPy
('22222222-2222-2222-2222-222222220011', 1, 'What does np.array([1,2,3]) create?', '["A Python list","A NumPy ndarray","A pandas Series","A dict"]', 1, 'np.array builds an ndarray.', 'curated', true, 'numpy'),
('22222222-2222-2222-2222-222222220011', 2, 'Scenario: You need column means from a DataFrame df. Best call?', '["df.mean(axis=1)","df.mean()","df.avg()","np.mean(df, rows=True)"]', 1, 'Default mean is per column (axis=0).', 'curated', true, 'pandas'),
('22222222-2222-2222-2222-222222220011', 2, 'df.loc vs df.iloc — iloc selects by?', '["Label","Integer position","SQL index","Column dtype"]', 1, 'iloc is position-based.', 'curated', true, 'pandas'),
('22222222-2222-2222-2222-222222220011', 3, 'Scenario: Merge customers and orders on customer_id keeping all customers.', '["inner join","left join on customers","right-only anti join","cross join"]', 1, 'Left join keeps all left rows.', 'curated', true, 'pandas'),
('22222222-2222-2222-2222-222222220011', 3, 'Broadcasting in NumPy means?', '["Network sync","Compatible shapes operate elementwise without explicit loops","Only GPU ops","CSV parsing"]', 1, 'Broadcasting expands shapes for vectorized ops.', 'curated', true, 'numpy'),
('22222222-2222-2222-2222-222222220011', 4, 'Scenario: Drop rows with any NaN in critical columns.', '["df.fillna(0)","df.dropna(subset=[...])","df.drop_duplicates()","df.reset_index()"]', 1, 'dropna(subset=) targets columns.', 'curated', true, 'pandas'),
('22222222-2222-2222-2222-222222220011', 5, 'Vectorization usually beats Python loops because?', '["More RAM always","Compiled/low-level ops on contiguous arrays","It disables GC","It uses SQL"]', 1, 'ndarray ops avoid interpreter overhead.', 'curated', true, 'numpy'),
-- ML
('22222222-2222-2222-2222-222222220012', 1, 'Supervised learning uses?', '["Only unlabeled data","Labeled input-output pairs","Only clustering","Random rewards"]', 1, 'Labels supervise the mapping.', 'curated', true, 'supervised'),
('22222222-2222-2222-2222-222222220012', 2, 'Scenario: Predict house prices from features. Problem type?', '["Classification","Regression","Clustering","Reinforcement"]', 1, 'Continuous target → regression.', 'curated', true, 'regression'),
('22222222-2222-2222-2222-222222220012', 2, 'Train/test split helps detect?', '["Hardware faults","Overfitting / generalization","CSS bugs","DNS issues"]', 1, 'Held-out data estimates generalization.', 'curated', true, 'validation'),
('22222222-2222-2222-2222-222222220012', 3, 'Scenario: Accuracy is high but rare fraud is missed. Check?', '["Only MAE","Precision/recall or F1 on minority class","Batch size only","Learning rate color"]', 1, 'Imbalance needs recall-oriented metrics.', 'curated', true, 'metrics'),
('22222222-2222-2222-2222-222222220012', 3, 'Overfitting means?', '["Underfitting train","Fits train well, generalizes poorly","Needs more epochs always","Ignores features"]', 1, 'Memorizes train noise.', 'curated', true, 'overfitting'),
('22222222-2222-2222-2222-222222220012', 4, 'Cross-validation primarily estimates?', '["GPU clock","Model performance stability across folds","Disk IOPS","Bundle size"]', 1, 'Multiple splits reduce luck of one split.', 'curated', true, 'validation'),
('22222222-2222-2222-2222-222222220012', 5, 'Scenario: Feature leakage suspicion. Symptom?', '["Low train accuracy","Unrealistically high validation using future info","Slow epochs","Missing labels only"]', 1, 'Leakage inflates metrics unrealistically.', 'curated', true, 'leakage'),
-- Git
('22222222-2222-2222-2222-222222220013', 1, 'git clone does what?', '["Deletes remote","Copies a repository locally","Formats disk","Runs CI"]', 1, 'Clone downloads the repo.', 'curated', true, 'basics'),
('22222222-2222-2222-2222-222222220013', 2, 'Scenario: Save work without committing permanently yet.', '["git push --force","git stash","git rebase -i","git tag"]', 1, 'stash shelves uncommitted changes.', 'curated', true, 'stash'),
('22222222-2222-2222-2222-222222220013', 2, 'git pull is roughly?', '["fetch + merge (or rebase)","only clone","only reset","only tag"]', 1, 'Pull updates from remote into current branch.', 'curated', true, 'remote'),
('22222222-2222-2222-2222-222222220013', 3, 'Scenario: Undo last local commit, keep changes staged.', '["git reset --hard HEAD~1","git reset --soft HEAD~1","git clean -fd","git push -f"]', 1, 'soft keeps index.', 'curated', true, 'reset'),
('22222222-2222-2222-2222-222222220013', 4, 'Rebase vs merge — rebase typically?', '["Deletes remotes","Replays commits for linear history","Creates two remotes","Skips commit messages"]', 1, 'Rebase rewrites onto new base.', 'curated', true, 'rebase'),
('22222222-2222-2222-2222-222222220013', 5, 'Scenario: Collaborator force-pushed. Safest next step?', '["git push --force immediately","Communicate, fetch, carefully rebase/reset with backup","Delete .git","Ignore"]', 1, 'Coordinate before rewriting history.', 'curated', true, 'collaboration'),
-- Networking
('22222222-2222-2222-2222-222222220014', 1, 'DNS primarily maps?', '["MAC to IP only","Names to IP addresses","HTML to CSS","Users to passwords"]', 1, 'DNS resolves names.', 'curated', true, 'dns'),
('22222222-2222-2222-2222-222222220014', 2, 'Scenario: Browser loads https://example.com. Port typically?', '["22","80","443","3306"]', 2, 'HTTPS uses 443.', 'curated', true, 'ports'),
('22222222-2222-2222-2222-222222220014', 2, 'TCP vs UDP — TCP provides?', '["Always faster video","Reliable ordered delivery (with overhead)","No handshake ever","Only broadcasts"]', 1, 'TCP is connection-oriented/reliable.', 'curated', true, 'tcp'),
('22222222-2222-2222-2222-222222220014', 3, 'Scenario: LAN device can''t reach internet but pings gateway. Likely?', '["Broken keyboard","Upstream/DNS/routing beyond gateway","Missing CSS","Full disk only"]', 1, 'Local OK suggests beyond gateway.', 'curated', true, 'troubleshooting'),
('22222222-2222-2222-2222-222222220014', 4, 'CIDR /24 means roughly?', '["2 hosts","256 addresses (usable less)","Only IPv6","One MAC"]', 1, '/24 is 256 addresses.', 'curated', true, 'cidr'),
('22222222-2222-2222-2222-222222220014', 5, 'TLS primarily protects?', '["Disk partitions","Confidentiality/integrity of data in transit","CPU cache","SQL indexes"]', 1, 'TLS secures the channel.', 'curated', true, 'tls'),
-- Linux
('22222222-2222-2222-2222-222222220015', 1, 'ls lists?', '["Processes only","Directory entries","Users only","Cron only"]', 1, 'ls lists files/dirs.', 'curated', true, 'cli'),
('22222222-2222-2222-2222-222222220015', 2, 'Scenario: Need file contents on stdout.', '["cd file","cat file","mkdir file","chmod file"]', 1, 'cat prints file.', 'curated', true, 'cli'),
('22222222-2222-2222-2222-222222220015', 2, 'chmod 755 typically means?', '["No access","Owner rwx, group/others rx","World writable","Setuid only"]', 1, '755 is common executable/dir mode.', 'curated', true, 'permissions'),
('22222222-2222-2222-2222-222222220015', 3, 'Scenario: Find which process holds port 3000.', '["ls /3000","ss/lsof/netstat approaches","git blame","npm audit only"]', 1, 'ss/lsof inspect listeners.', 'curated', true, 'process'),
('22222222-2222-2222-2222-222222220015', 4, 'stdin/stdout/stderr are?', '["Kernel modules","Standard I/O streams","RAID levels","SELinux booleans only"]', 1, 'Standard streams for CLI I/O.', 'curated', true, 'io'),
('22222222-2222-2222-2222-222222220015', 5, 'Scenario: Disk full on /var. First check?', '["Reinstall kernel","df -h / du to find large dirs","Disable SSH forever","Random rm -rf /"]', 1, 'Measure then target cleanup.', 'curated', true, 'ops'),
-- Threats
('22222222-2222-2222-2222-222222220016', 1, 'Phishing aims to?', '["Compile code","Trick users into secrets/actions","Defragment disks","Optimize CSS"]', 1, 'Social engineering for credentials/actions.', 'curated', true, 'phishing'),
('22222222-2222-2222-2222-222222220016', 2, 'Scenario: User pastes password into fake login page. Risk?', '["Credential theft","Faster Wi-Fi","Better SEO","Free RAM"]', 0, 'Credentials harvested.', 'curated', true, 'phishing'),
('22222222-2222-2222-2222-222222220016', 3, 'Defense in depth means?', '["One firewall only","Multiple layered controls","Disable logging","Share root keys"]', 1, 'Layers reduce single-point failure.', 'curated', true, 'defense'),
('22222222-2222-2222-2222-222222220016', 3, 'Scenario: SQL injection prevention baseline?', '["String concat SQL","Parameterized queries / ORM binds","Disable HTTPS","Store passwords plaintext"]', 1, 'Bound parameters stop classic SQLi.', 'curated', true, 'injection'),
('22222222-2222-2222-2222-222222220016', 4, 'Zero-day refers to?', '["Day zero payroll","Unknown/unpatched vulnerability exploit","Empty sprint","TTL=0 DNS only"]', 1, 'No vendor fix yet / unknown publicly.', 'curated', true, 'vuln'),
('22222222-2222-2222-2222-222222220016', 5, 'Scenario: Ransomware on file share. Immediate priority?', '["Post on social","Isolate, preserve evidence, restore from clean backups","Pay without IR plan always","Reimage without notes"]', 1, 'Contain + recover safely.', 'curated', true, 'ir'),
-- TypeScript
('22222222-2222-2222-2222-222222220017', 1, 'TypeScript adds what to JS?', '["CSS modules only","Static types (and tooling)","A new browser","SQL"]', 1, 'TS is typed JS superset.', 'curated', true, 'basics'),
('22222222-2222-2222-2222-222222220017', 2, 'Scenario: Prop might be missing. Useful type?', '["any forever","optional property with ?","eval","var only"]', 1, 'Optional props use ?.', 'curated', true, 'optional'),
('22222222-2222-2222-2222-222222220017', 3, 'interface vs type — both can describe?', '["Only classes","Object shapes","Only CSS","Only WASM"]', 1, 'Both model object types.', 'curated', true, 'types'),
('22222222-2222-2222-2222-222222220017', 3, 'Scenario: Narrow unknown JSON field safely.', '["Force as any","Type guards / validation","Ignore TS","Use eval"]', 1, 'Narrow with checks.', 'curated', true, 'narrowing'),
('22222222-2222-2222-2222-222222220017', 4, 'Generics help?', '["Delete node_modules","Reusable typed abstractions","Disable eslint","Ship sourcemaps only"]', 1, 'Parameterized types.', 'curated', true, 'generics'),
('22222222-2222-2222-2222-222222220017', 5, 'Scenario: Library types missing. Common approach?', '["Rewrite React","@types packages or declare modules","Ban imports","Use PHP"]', 1, 'DefinitelyTyped / ambient decls.', 'curated', true, 'tooling'),
-- Node
('22222222-2222-2222-2222-222222220018', 1, 'Node.js is primarily?', '["Browser CSS engine","JS runtime outside the browser","SQL database","GPU driver"]', 1, 'Server-side JS runtime.', 'curated', true, 'basics'),
('22222222-2222-2222-2222-222222220018', 2, 'Scenario: Read a file asynchronously in Node.', '["alert()","fs.promises.readFile / fs.readFile","document.write","localStorage"]', 1, 'fs module for files.', 'curated', true, 'fs'),
('22222222-2222-2222-2222-222222220018', 2, 'npm install adds deps to?', '["/etc","node_modules (+ lockfile)","Windows registry only","BIOS"]', 1, 'Packages land in node_modules.', 'curated', true, 'npm'),
('22222222-2222-2222-2222-222222220018', 3, 'Scenario: Express 404 for unknown routes. Place middleware?', '["Before all routes only","After routes as catch-all","Inside CSS","In DNS"]', 1, '404 handlers sit after routes.', 'curated', true, 'express'),
('22222222-2222-2222-2222-222222220018', 4, 'Event loop enables?', '["Only sync CPU","Non-blocking I/O concurrency model","SQL ACID alone","GPU kernels"]', 1, 'Async I/O multiplexed on the loop.', 'curated', true, 'async'),
('22222222-2222-2222-2222-222222220018', 5, 'Scenario: Memory leak suspicion in long-lived process.', '["Ignore heap","Heap snapshots / monitoring retainers","Disable logs forever","Delete package-lock only"]', 1, 'Profile retained objects.', 'curated', true, 'ops'),
-- System design
('22222222-2222-2222-2222-222222220019', 1, 'Horizontal scaling means?', '["Bigger single CPU only","Add more machines","Delete replicas","Only CSS minify"]', 1, 'Scale out with more nodes.', 'curated', true, 'scaling'),
('22222222-2222-2222-2222-222222220019', 2, 'Scenario: Spike reads on product pages. Common help?', '["Turn off CDN","Caching / CDN","Store passwords in cookies","Disable indexes"]', 1, 'Caches absorb read spikes.', 'curated', true, 'cache'),
('22222222-2222-2222-2222-222222220019', 3, 'Load balancer purpose?', '["Compile TS","Distribute traffic across instances","Replace databases","Encrypt disks only"]', 1, 'Spreads requests.', 'curated', true, 'lb'),
('22222222-2222-2222-2222-222222220019', 3, 'Scenario: Strong consistency vs availability tradeoff often discussed as?', '["CAP-related tensions","Only MVC","Only CRUD UI","Flexbox"]', 0, 'Distributed tradeoffs (CAP/PACELC).', 'curated', true, 'consistency'),
('22222222-2222-2222-2222-222222220019', 4, 'Idempotent API design helps?', '["CSS specificity","Safe retries without duplicate side effects","Faster GC always","Skip auth"]', 1, 'Retries won''t double-charge etc.', 'curated', true, 'apis'),
('22222222-2222-2222-2222-222222220019', 5, 'Scenario: Global users, low latency reads. Pattern?', '["Single region only always","Geo replication / edge caching thoughtfully","One SQLite laptop","ChatGPT as DB"]', 1, 'Bring data closer carefully.', 'curated', true, 'geo'),
-- Extra scenarios for core skills
('22222222-2222-2222-2222-222222220001', 2, 'Scenario: Parse CSV lines into dicts carefully. Watch for?', '["GPU heat","Quoted commas / encoding","CSS grids","DNS TTLs"]', 1, 'CSV edge cases break naive splits.', 'curated', true, 'parsing'),
('22222222-2222-2222-2222-222222220001', 3, 'Scenario: Function must not mutate caller list. Prefer?', '["list.append in place","Return a new list","Use global","Delete input"]', 1, 'Avoid surprising mutation.', 'curated', true, 'immutability'),
('22222222-2222-2222-2222-222222220002', 2, 'Scenario: Report needs unique emails from users table.', '["SELECT *","SELECT DISTINCT email","DELETE email","VACUUM email"]', 1, 'DISTINCT dedupes.', 'curated', true, 'distinct'),
('22222222-2222-2222-2222-222222220002', 4, 'Scenario: Slow query on large orders. First investigate?', '["Rewrite in Java","EXPLAIN / indexes / filters","Disable WAL forever","Random DROP INDEX"]', 1, 'Explain plans guide indexing.', 'curated', true, 'performance'),
('22222222-2222-2222-2222-222222220006', 2, 'Scenario: Button click does nothing. First check?', '["Rewrite OS","Listener registration / console errors","Buy new domain","Disable HTTPS"]', 1, 'Verify handlers and errors.', 'curated', true, 'dom'),
('22222222-2222-2222-2222-222222220006', 3, 'Scenario: Race between two fetches updating UI. Risk?', '["Stale state overwrites","Faster CSS","Better SEO automatically","No risk"]', 0, 'Last write may be outdated.', 'curated', true, 'async'),
('22222222-2222-2222-2222-222222220007', 2, 'Scenario: List reorders oddly on edit. Likely?', '["Missing keys / bad key strategy","Too much RAM","DNS","TLS version"]', 0, 'Unstable keys confuse reconciliation.', 'curated', true, 'keys'),
('22222222-2222-2222-2222-222222220007', 4, 'Scenario: Expensive child re-renders. Consider?', '["Ban hooks","Memoization / state placement","Inline HTML comments only","Remove React"]', 1, 'Control render boundaries.', 'curated', true, 'perf'),
('22222222-2222-2222-2222-222222220008', 2, 'Scenario: Creating a resource via API. Method?', '["GET","POST","TRACE as default","CONNECT"]', 1, 'POST commonly creates.', 'curated', true, 'http'),
('22222222-2222-2222-2222-222222220008', 3, 'Scenario: Client retries payment POST. Design need?', '["Idempotency keys / safe semantics","Larger images","Disable logs","Random UUIDs in CSS"]', 0, 'Avoid duplicate charges.', 'curated', true, 'idempotency'),
('22222222-2222-2222-2222-222222220010', 2, 'Scenario: Session cookie stolen via XSS. Mitigations include?', '["HttpOnly cookies + CSP + encoding","Store JWT in localStorage only always","Disable HTTPS","Inline eval everywhere"]', 0, 'Hardening reduces XSS impact.', 'curated', true, 'xss'),
('22222222-2222-2222-2222-222222220003', 2, 'Scenario: A/B test needs significance check. Related idea?', '["Flexbox","Hypothesis testing / p-values carefully","Git rebase","DNSSEC only"]', 1, 'Stats underpins experiment reads.', 'curated', true, 'inference'),
('22222222-2222-2222-2222-222222220004', 2, 'Scenario: Executive wants trend over months. Prefer?', '["Pie of 40 categories","Line chart over time","Word cloud of dates","3D exploding pie"]', 1, 'Lines show temporal trends.', 'curated', true, 'charts'),
('22222222-2222-2222-2222-222222220009', 2, 'Scenario: Orders reference customers. Enforce with?', '["Foreign key","CSS anchor","DNS CNAME","npm peer"]', 0, 'FKs enforce referential integrity.', 'curated', true, 'modeling'),
('22222222-2222-2222-2222-222222220005', 2, 'Scenario: Layout breaks on mobile. First tools?', '["Buy new laptop","DevTools responsive + fluid CSS","Disable JS forever","Larger PNGs"]', 1, 'Responsive debugging basics.', 'curated', true, 'responsive');
