-- Seed catalog: roles, skills, questions, resources
-- Fixed UUIDs for stable references

-- Roles
insert into public.roles (id, slug, title, description) values
  ('11111111-1111-1111-1111-111111111001', 'data-analyst', 'Data Analyst', 'Turn raw data into insights with SQL, stats, and visualization.'),
  ('11111111-1111-1111-1111-111111111002', 'frontend-dev', 'Frontend Developer', 'Build accessible, performant user interfaces with modern web tech.'),
  ('11111111-1111-1111-1111-111111111003', 'backend-dev', 'Backend Developer', 'Design APIs, data models, and reliable server-side systems.');

-- Skills
insert into public.skills (id, slug, name, category, prerequisites) values
  ('22222222-2222-2222-2222-222222220001', 'python-basics', 'Python Basics', 'programming', '{}'),
  ('22222222-2222-2222-2222-222222220002', 'sql', 'SQL', 'data', '{}'),
  ('22222222-2222-2222-2222-222222220003', 'statistics', 'Statistics', 'data', array['22222222-2222-2222-2222-222222220001'::uuid]),
  ('22222222-2222-2222-2222-222222220004', 'data-viz', 'Data Visualization', 'data', array['22222222-2222-2222-2222-222222220002'::uuid]),
  ('22222222-2222-2222-2222-222222220005', 'html-css', 'HTML & CSS', 'web', '{}'),
  ('22222222-2222-2222-2222-222222220006', 'javascript', 'JavaScript', 'web', array['22222222-2222-2222-2222-222222220005'::uuid]),
  ('22222222-2222-2222-2222-222222220007', 'react', 'React', 'web', array['22222222-2222-2222-2222-222222220006'::uuid]),
  ('22222222-2222-2222-2222-222222220008', 'apis', 'REST APIs', 'backend', array['22222222-2222-2222-2222-222222220001'::uuid]),
  ('22222222-2222-2222-2222-222222220009', 'databases', 'Databases', 'backend', array['22222222-2222-2222-2222-222222220002'::uuid]),
  ('22222222-2222-2222-2222-222222220010', 'auth-security', 'Auth & Security', 'backend', array['22222222-2222-2222-2222-222222220008'::uuid]);

-- Role skills
insert into public.role_skills (role_id, skill_id, required_level, importance) values
  -- Data Analyst
  ('11111111-1111-1111-1111-111111111001', '22222222-2222-2222-2222-222222220001', 7, 4),
  ('11111111-1111-1111-1111-111111111001', '22222222-2222-2222-2222-222222220002', 9, 5),
  ('11111111-1111-1111-1111-111111111001', '22222222-2222-2222-2222-222222220003', 8, 5),
  ('11111111-1111-1111-1111-111111111001', '22222222-2222-2222-2222-222222220004', 8, 4),
  -- Frontend
  ('11111111-1111-1111-1111-111111111002', '22222222-2222-2222-2222-222222220005', 8, 5),
  ('11111111-1111-1111-1111-111111111002', '22222222-2222-2222-2222-222222220006', 9, 5),
  ('11111111-1111-1111-1111-111111111002', '22222222-2222-2222-2222-222222220007', 9, 5),
  ('11111111-1111-1111-1111-111111111002', '22222222-2222-2222-2222-222222220008', 6, 3),
  -- Backend
  ('11111111-1111-1111-1111-111111111003', '22222222-2222-2222-2222-222222220001', 8, 5),
  ('11111111-1111-1111-1111-111111111003', '22222222-2222-2222-2222-222222220008', 9, 5),
  ('11111111-1111-1111-1111-111111111003', '22222222-2222-2222-2222-222222220009', 8, 5),
  ('11111111-1111-1111-1111-111111111003', '22222222-2222-2222-2222-222222220010', 8, 4),
  ('11111111-1111-1111-1111-111111111003', '22222222-2222-2222-2222-222222220002', 7, 4);

-- Resources
insert into public.resources (id, skill_id, title, url, type, difficulty) values
  ('33333333-3333-3333-3333-333333330001', '22222222-2222-2222-2222-222222220001', 'Python Official Tutorial', 'https://docs.python.org/3/tutorial/', 'docs', 2),
  ('33333333-3333-3333-3333-333333330002', '22222222-2222-2222-2222-222222220002', 'SQLBolt Interactive Lessons', 'https://sqlbolt.com/', 'course', 2),
  ('33333333-3333-3333-3333-333333330003', '22222222-2222-2222-2222-222222220003', 'Khan Academy Statistics', 'https://www.khanacademy.org/math/statistics-probability', 'course', 3),
  ('33333333-3333-3333-3333-333333330004', '22222222-2222-2222-2222-222222220004', 'Observable Plot Intro', 'https://observablehq.com/plot/', 'docs', 3),
  ('33333333-3333-3333-3333-333333330005', '22222222-2222-2222-2222-222222220005', 'MDN HTML & CSS', 'https://developer.mozilla.org/en-US/docs/Learn_web_development', 'docs', 2),
  ('33333333-3333-3333-3333-333333330006', '22222222-2222-2222-2222-222222220006', 'JavaScript.info', 'https://javascript.info/', 'course', 3),
  ('33333333-3333-3333-3333-333333330007', '22222222-2222-2222-2222-222222220007', 'React Docs Learn', 'https://react.dev/learn', 'docs', 3),
  ('33333333-3333-3333-3333-333333330008', '22222222-2222-2222-2222-222222220008', 'MDN REST APIs', 'https://developer.mozilla.org/en-US/docs/Glossary/REST', 'article', 3),
  ('33333333-3333-3333-3333-333333330009', '22222222-2222-2222-2222-222222220009', 'Postgres Tutorial', 'https://www.postgresqltutorial.com/', 'course', 3),
  ('33333333-3333-3333-3333-333333330010', '22222222-2222-2222-2222-222222220010', 'OWASP Top 10', 'https://owasp.org/www-project-top-ten/', 'article', 4);

-- Questions (curated, ~5 per skill across difficulties)
insert into public.questions (skill_id, difficulty, stem, options, correct_index, explanation, source, reviewed) values
-- Python
('22222222-2222-2222-2222-222222220001', 1, 'Which keyword defines a function in Python?', '["func","def","function","lambda"]', 1, 'Functions are defined with the def keyword.', 'curated', true),
('22222222-2222-2222-2222-222222220001', 2, 'What does len([1,2,3]) return?', '["2","3","4","Error"]', 1, 'len returns the number of items in the list.', 'curated', true),
('22222222-2222-2222-2222-222222220001', 3, 'What is the output of bool([])?', '["True","False","None","Error"]', 1, 'Empty collections are falsy in Python.', 'curated', true),
('22222222-2222-2222-2222-222222220001', 4, 'Which collection is immutable?', '["list","dict","set","tuple"]', 3, 'Tuples cannot be changed after creation.', 'curated', true),
('22222222-2222-2222-2222-222222220001', 5, 'What does *args collect in a function signature?', '["Keyword args","Positional extras as a tuple","Only lists","Global vars"]', 1, '*args packs extra positional arguments into a tuple.', 'curated', true),
-- SQL
('22222222-2222-2222-2222-222222220002', 1, 'Which clause filters rows in SQL?', '["ORDER BY","WHERE","GROUP BY","HAVING"]', 1, 'WHERE filters rows before aggregation.', 'curated', true),
('22222222-2222-2222-2222-222222220002', 2, 'What does SELECT DISTINCT remove?', '["Nulls","Duplicate rows","Columns","Indexes"]', 1, 'DISTINCT returns unique row combinations.', 'curated', true),
('22222222-2222-2222-2222-222222220002', 3, 'Which JOIN returns only matching rows from both tables?', '["LEFT","RIGHT","INNER","FULL"]', 2, 'INNER JOIN keeps intersecting matches.', 'curated', true),
('22222222-2222-2222-2222-222222220002', 4, 'HAVING is typically used with?', '["INSERT","Aggregates / GROUP BY","VACUUM","INDEX"]', 1, 'HAVING filters groups after aggregation.', 'curated', true),
('22222222-2222-2222-2222-222222220002', 5, 'Which isolates a transaction from dirty reads in Postgres default?', '["READ UNCOMMITTED","READ COMMITTED","SERIALIZABLE only","No isolation"]', 1, 'Postgres default isolation is READ COMMITTED.', 'curated', true),
-- Statistics
('22222222-2222-2222-2222-222222220003', 1, 'The mean is also called the?', '["Mode","Average","Median","Range"]', 1, 'Mean is the arithmetic average.', 'curated', true),
('22222222-2222-2222-2222-222222220003', 2, 'Median of [1,3,5] is?', '["1","3","5","4"]', 1, 'Middle value of a sorted list.', 'curated', true),
('22222222-2222-2222-2222-222222220003', 3, 'Variance measures?', '["Central tendency","Spread around the mean","Correlation only","Sample size"]', 1, 'Variance quantifies dispersion.', 'curated', true),
('22222222-2222-2222-2222-222222220003', 4, 'A p-value below 0.05 often means?', '["Proof of causation","Result is practically large","Evidence against null at common alpha","Sample is biased"]', 2, 'Common significance threshold for rejecting H0.', 'curated', true),
('22222222-2222-2222-2222-222222220003', 5, 'Correlation near 0 suggests?', '["Strong positive link","Strong negative link","Little linear association","Causation"]', 2, 'Near-zero correlation implies weak linear relationship.', 'curated', true),
-- Data viz
('22222222-2222-2222-2222-222222220004', 1, 'Best chart for part-to-whole shares?', '["Scatter","Pie/Donut","Line","Histogram"]', 1, 'Pie/donut shows composition.', 'curated', true),
('22222222-2222-2222-2222-222222220004', 2, 'Line charts are best for?', '["Categories only","Trends over time","Maps","Networks"]', 1, 'Lines emphasize change over a continuous axis.', 'curated', true),
('22222222-2222-2222-2222-222222220004', 3, 'A histogram visualizes?', '["Distribution of a numeric variable","Network hops","SQL plans","Git history"]', 0, 'Bins show frequency distribution.', 'curated', true),
('22222222-2222-2222-2222-222222220004', 4, 'Dual y-axes can be misleading because?', '["They are colorful","Scales can exaggerate relationships","Browsers block them","SQL forbids them"]', 1, 'Independent scales can invent correlations.', 'curated', true),
('22222222-2222-2222-2222-222222220004', 5, 'Colorblind-safe palettes primarily avoid relying on?', '["Labels","Red-green contrast alone","Titles","Gridlines"]', 1, 'Red-green is a common deficiency pair.', 'curated', true),
-- HTML/CSS
('22222222-2222-2222-2222-222222220005', 1, 'Which tag creates a hyperlink?', '["<link>","<a>","<href>","<url>"]', 1, 'Anchor <a> creates links.', 'curated', true),
('22222222-2222-2222-2222-222222220005', 2, 'CSS box model order outside-in?', '["Content, padding, border, margin","Margin, border, padding, content","Border, margin, padding, content","Padding, content, margin, border"]', 1, 'Margin wraps border wraps padding wraps content.', 'curated', true),
('22222222-2222-2222-2222-222222220005', 3, 'Flexbox main axis is controlled by?', '["align-items","justify-content","z-index","float"]', 1, 'justify-content aligns along the main axis.', 'curated', true),
('22222222-2222-2222-2222-222222220005', 4, 'Semantic HTML helps?', '["Only SEO spam","Accessibility and meaning","Disable CSS","Replace JS"]', 1, 'Semantics aid a11y and structure.', 'curated', true),
('22222222-2222-2222-2222-222222220005', 5, 'rem units are relative to?', '["Parent font size","Root element font size","Viewport only","Device DPI only"]', 1, 'rem uses the root (html) font-size.', 'curated', true),
-- JavaScript
('22222222-2222-2222-2222-222222220006', 1, 'Which declares a block-scoped variable?', '["var","let","function","with"]', 1, 'let is block-scoped.', 'curated', true),
('22222222-2222-2222-2222-222222220006', 2, '=== compares?', '["Value only","Value and type","References only","Prototypes only"]', 1, 'Strict equality checks type and value.', 'curated', true),
('22222222-2222-2222-2222-222222220006', 3, 'Array.map returns?', '["Mutated original","A new array","A boolean","undefined"]', 1, 'map produces a new array.', 'curated', true),
('22222222-2222-2222-2222-222222220006', 4, 'Promises represent?', '["Sync loops","Future completion of async work","CSS animations","DOM nodes"]', 1, 'Promises model async results.', 'curated', true),
('22222222-2222-2222-2222-222222220006', 5, 'Event bubbling means events?', '["Stop at target","Propagate from target toward root","Skip capture","Ignore handlers"]', 1, 'Bubbling goes upward after the target phase.', 'curated', true),
-- React
('22222222-2222-2222-2222-222222220007', 1, 'JSX must have?', '["Multiple roots always","A single parent element (or fragment)","No expressions","Only strings"]', 1, 'Return one parent or <>fragment</>.', 'curated', true),
('22222222-2222-2222-2222-222222220007', 2, 'useState returns?', '["Only a value","[value, setter]","A ref","A reducer"]', 1, 'State hook returns pair.', 'curated', true),
('22222222-2222-2222-2222-222222220007', 3, 'Keys in lists help React?', '["Style items","Reconcile identity across renders","Call APIs","Replace props"]', 1, 'Stable keys improve reconciliation.', 'curated', true),
('22222222-2222-2222-2222-222222220007', 4, 'useEffect runs?', '["Only on server","After paint for syncing effects","Instead of render","Inside JSX only"]', 1, 'Effects run after commit/paint.', 'curated', true),
('22222222-2222-2222-2222-222222220007', 5, 'Lifting state means?', '["Using Redux only","Moving shared state to a common ancestor","Deleting props","SSR only"]', 1, 'Share state via a parent.', 'curated', true),
-- APIs
('22222222-2222-2222-2222-222222220008', 1, 'HTTP GET should be?', '["Unsafe","Idempotent & safe","Always POST body","Stateful only"]', 1, 'GET is safe and idempotent.', 'curated', true),
('22222222-2222-2222-2222-222222220008', 2, 'Status 404 means?', '["OK","Created","Not Found","Unauthorized"]', 2, '404 = resource missing.', 'curated', true),
('22222222-2222-2222-2222-222222220008', 3, 'JSON is commonly sent with Content-Type?', '["text/plain","application/json","image/png","multipart only"]', 1, 'application/json is standard.', 'curated', true),
('22222222-2222-2222-2222-222222220008', 4, 'REST resources are typically identified by?', '["Cookies only","URLs / URIs","SQL tables only","WebSockets only"]', 1, 'Resources map to URIs.', 'curated', true),
('22222222-2222-2222-2222-222222220008', 5, 'Idempotent PUT means repeating it?', '["Creates duplicates","Yields same resource state","Deletes always","Requires GraphQL"]', 1, 'Same effect when repeated.', 'curated', true),
-- Databases
('22222222-2222-2222-2222-222222220009', 1, 'A primary key must be?', '["Nullable","Unique per row","Always text","Unindexed"]', 1, 'PKs uniquely identify rows.', 'curated', true),
('22222222-2222-2222-2222-222222220009', 2, 'Normalization reduces?', '["Backups","Redundant data","RAM forever","SSL"]', 1, 'Normal forms reduce duplication.', 'curated', true),
('22222222-2222-2222-2222-222222220009', 3, 'An index mainly speeds up?', '["Writes always","Lookups / filters","Network latency","CSS"]', 1, 'Indexes accelerate reads/filters.', 'curated', true),
('22222222-2222-2222-2222-222222220009', 4, 'ACID Atomicity means?', '["All-or-nothing transactions","Always cache","Async only","Indexed columns"]', 0, 'Transactions commit fully or roll back.', 'curated', true),
('22222222-2222-2222-2222-222222220009', 5, 'Foreign keys enforce?', '["UI themes","Referential integrity","CSS grid","JWT expiry"]', 1, 'FKs keep relationships valid.', 'curated', true),
-- Auth/Security
('22222222-2222-2222-2222-222222220010', 1, 'Passwords should be stored as?', '["Plain text","Reversible encryption only","Salted hashes","Emails"]', 2, 'Use slow salted hashes.', 'curated', true),
('22222222-2222-2222-2222-222222220010', 2, 'HTTPS primarily protects?', '["Disk space","Data in transit via TLS","SQL syntax","Font loading"]', 1, 'TLS encrypts transit.', 'curated', true),
('22222222-2222-2222-2222-222222220010', 3, 'XSS attacks inject?', '["SQL only","Malicious scripts into pages","CSS resets","Docker images"]', 1, 'Cross-site scripting injects script.', 'curated', true),
('22222222-2222-2222-2222-222222220010', 4, 'CSRF tricks a browser into?', '["Faster CSS","Unwanted authenticated requests","Deleting indexes","Compiling TS"]', 1, 'Cross-site request forgery abuses cookies/sessions.', 'curated', true),
('22222222-2222-2222-2222-222222220010', 5, 'Principle of least privilege means?', '["Admin for all","Grant only needed access","Disable MFA","Share API keys in git"]', 1, 'Minimize permissions.', 'curated', true);
