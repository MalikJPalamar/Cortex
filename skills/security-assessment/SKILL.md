---
name: security-assessment
description: Security assessment and penetration testing methodology. USE WHEN auditing a system, website, API, or infrastructure for vulnerabilities. Authorized testing only.
---

# Security Assessment — Authorized Testing

For authorized security testing, defensive security, and infrastructure auditing. Only use with explicit authorization from the system owner.

## Assessment Types

### 1. Web Application Audit
**Invoke:** "Security audit [URL]"

**Checklist:**
- [ ] **Information Gathering:** tech stack, headers, exposed endpoints, robots.txt, sitemap
- [ ] **Authentication:** login flow, password policy, session management, MFA presence
- [ ] **Authorization:** access control, IDOR, privilege escalation paths
- [ ] **Input Validation:** XSS vectors, SQL injection points, command injection
- [ ] **Configuration:** HTTPS enforcement, security headers, CORS policy, cookie flags
- [ ] **Data Exposure:** sensitive data in responses, error messages, stack traces
- [ ] **API Security:** rate limiting, authentication, input validation, versioning

**Output format:**
```
TARGET: [URL]
AUTHORIZATION: [who authorized, date]

FINDINGS:
| # | Severity | Category | Finding | Evidence |
|---|----------|----------|---------|----------|
| 1 | Critical | AuthN    | [desc]  | [proof]  |

RECOMMENDATIONS:
1. [fix for finding 1]

OVERALL RISK: [Critical | High | Medium | Low]
```

### 2. Infrastructure Audit
**Invoke:** "Audit infrastructure for [VPS/system]"

**Checklist:**
- [ ] **Exposed Services:** open ports, unnecessary services
- [ ] **SSH:** key-only auth, root login disabled, fail2ban
- [ ] **Docker:** container isolation, image provenance, secrets in env
- [ ] **Updates:** pending security patches, EOL software
- [ ] **Secrets:** API keys in env vars, exposed in logs/history, rotation status
- [ ] **Backups:** backup strategy, tested restore, offsite copies
- [ ] **Monitoring:** log aggregation, alerting, intrusion detection
- [ ] **Firewall:** UFW/iptables rules, default deny, unnecessary open ports

### 3. API Security Review
**Invoke:** "Review API security for [endpoint/service]"

**Checklist:**
- [ ] **Authentication:** API key management, OAuth flow, token expiration
- [ ] **Rate Limiting:** per-key, per-IP, burst protection
- [ ] **Input Validation:** schema validation, size limits, type checking
- [ ] **Output Filtering:** no sensitive data in responses, proper error codes
- [ ] **CORS:** restricted origins, no wildcard in production
- [ ] **Logging:** request logging without sensitive data, audit trail

### 4. Secret Rotation Audit
**Invoke:** "Audit secrets for [system/repo]"

**Procedure:**
1. Scan for exposed keys: `grep -rn "sk-\|ghp_\|AIza\|GOCSPX\|Bearer" . --include="*.{md,json,yml,sh,py,env}"`
2. Check git history: `git log -20 -p | grep -c "sk-ant-\|sk-or-v1-"`
3. Check environment: `env | grep -i "key\|token\|secret\|password"`
4. Verify rotation dates for each key found
5. Check for keys in Docker images: `docker inspect --format='{{.Config.Env}}' [container]`

**Output format:**
```
SECRET AUDIT: [system]

| Secret | Location | Last Rotated | Status |
|--------|----------|-------------|--------|
| [name] | [where]  | [date]      | ✅/⚠️/❌ |

EXPOSED IN GIT HISTORY: [yes/no, commit count]
REMEDIATION: [BFG clean needed? Key rotation needed?]
```

### 5. Centaurion-Specific Security

**VPS1 audit:**
```bash
# Quick security posture check
CENTAURION_REPO=~/Centaurion bash deploy/vps1/health-check.sh
# Check for exposed secrets
grep -rn "sk-\|ghp_\|AIza" ~/Centaurion/ --include="*.{md,json,sh}" | grep -v "REPLACE_WITH\|example\|verify-production"
# Check SSH config
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config
# Check open ports
ss -tlnp | grep LISTEN
```

**VPS2 audit:**
```bash
# Docker containers
docker ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"
# Neo4j auth
docker exec neo4j env | grep NEO4J_AUTH
# NanoClaw secrets
grep -c "API_KEY\|TOKEN\|SECRET" ~/nanoclaw/.env
```

## Routing

- **Reconnaissance/scanning** (read-only): auto-execute
- **Active testing** (sending payloads): route to Malik
- **Remediation** (changing configs): route to Malik
- **Secret rotation**: ai_with_review (high stakes, medium reversibility)

## IMPORTANT

Only perform security testing on systems you own or have explicit written authorization to test. Centaurion's VPS1, VPS2, and associated services are authorized. Client systems require separate authorization.
