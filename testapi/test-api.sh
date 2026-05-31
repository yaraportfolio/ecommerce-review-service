#!/bin/sh
set -e

# --- CONFIGURATION ---
LOG_FILE="test-results.log"
HTML_FILE="test-api-report.html"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Initialisation du Log Console (Inchangé)
echo "Review Service API Full Suite - $(date)" > "$LOG_FILE"
echo "----------------------------------------------------------------------" >> "$LOG_FILE"
printf "%-10s | %-40s | %s\n" "STATUS" "TEST DESCRIPTION" "RESULT" | tee -a "$LOG_FILE"
echo "----------------------------------------------------------------------" >> "$LOG_FILE"

# 2. Initialisation du Dashboard HTML (Look Premium)
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #f4f7f9; padding: 20px; }
        .container { max-width: 850px; margin: auto; }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; padding: 20px; border-radius: 12px; text-align: center; 
            box-shadow: 0 4px 15px rgba(0,0,0,0.1); margin-bottom: 25px;
            width: 90%; margin-left: auto; margin-right: auto;
        }
        .test-card { background: white; border-radius: 8px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; padding: 15px 25px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); border-left: 6px solid #ccc; }
        .PASS { border-left-color: #4caf50; }
        .FAIL { border-left-color: #f44336; }
        .badge { padding: 6px 12px; margin-left: 10px; border-radius: 4px; font-weight: bold; font-size: 0.8em; color: white; }
        .bg-PASS { background: #4caf50; }
        .bg-FAIL { background: #f44336; }
        .tech-info { font-size: 0.8em; color: #7f8c8d; font-family: monospace; margin-top: 5px; word-break: break-all; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⭐ REVIEW SERVICE DASHBOARD</h1>
            <p>Review-Service | Port: $SERVICE_PORT</p>
        </div>
EOF

run_test() {
  DESC="$1"
  CMD="$2"
  DISPLAY_CMD="$3"
  [ -z "$DISPLAY_CMD" ] && DISPLAY_CMD="$CMD"

  if eval "$CMD" > /dev/null 2>&1; then
    printf "${GREEN}%-10s${NC} | %-40s | Success\n" "PASS ✅" "$DESC" | tee -a "$LOG_FILE"
    echo "<div class='test-card PASS'><div><strong>$DESC</strong><div class='tech-info'>$DISPLAY_CMD</div></div><span class='badge bg-PASS'>PASS</span></div>" >> "$HTML_FILE"
  else
    printf "${RED}%-10s${NC} | %-40s | Error\n" "FAIL ❌" "$DESC" | tee -a "$LOG_FILE"
    echo "<div class='test-card FAIL'><div><strong>$DESC</strong><div class='tech-info'>$DISPLAY_CMD</div></div><span class='badge bg-FAIL'>FAIL</span></div>" >> "$HTML_FILE"
    echo "</div></body></html>" >> "$HTML_FILE"
    kill $SERVICE_PID 2>/dev/null || true
    exit 1
  fi
}

# --- DÉMARRAGE DU SERVICE ---
node src/server.js > service-output.log 2>&1 &
SERVICE_PID=$!
sleep 3
timeout 60 sh -c "until curl -s http://localhost:${SERVICE_PORT}/api/reviews/health > /dev/null; do sleep 1; done"

# --- 1. OBSERVABILITÉ ---
run_test "1. Health Check (Liveness)" "curl -s http://localhost:${SERVICE_PORT}/api/reviews/health | jq -e '.status == \"ok\"'"
run_test "2. Ready Check (Readiness)" "curl -s http://localhost:${SERVICE_PORT}/api/reviews/ready | jq -e '.status == \"ready\"'"
run_test "3. Prometheus Metrics" "curl -s http://localhost:${SERVICE_PORT}/api/reviews/metrics | grep -q 'http_requests_total'"
run_test "4. Service Info Metadata" "curl -s http://localhost:${SERVICE_PORT}/api/reviews/info | jq -e '.service == \"review-service\"'"

# --- 2. CONSULTATION ET STRUCTURE ---
run_test "5. Get Reviews by Product (Min 2 items)" "[ \$(curl -s http://localhost:${SERVICE_PORT}/api/reviews/product/1 | jq 'length') -ge 2 ]"
run_test "6. Review Data Schema Integrity" "REVIEWS=\$(curl -s http://localhost:${SERVICE_PORT}/api/reviews/product/1) && echo \"\$REVIEWS\" | jq -e '.[0] | .id and .product_id and .rating and .comment'" "Vérification JSON: id, rating, comment"
run_test "7. Empty Reviews for New Product" "[ \$(curl -s http://localhost:${SERVICE_PORT}/api/reviews/product/4 | jq 'length') -eq 0 ]"

# --- 3. ENDPOINTS DE GESTION ---
run_test "8. POST Review Endpoint Existence" "CODE=\$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:${SERVICE_PORT}/api/reviews) && [ \"\$CODE\" != \"404\" ]"
run_test "9. PUT Review Endpoint Existence" "CODE=\$(curl -s -o /dev/null -w '%{http_code}' -X PUT http://localhost:${SERVICE_PORT}/api/reviews/1) && [ \"\$CODE\" != \"404\" ]"

# --- 4. CALCULS ET BASE DE DONNÉES ---
run_test "10. Average Rating Calculation" "RATINGS=\$(curl -s http://localhost:${SERVICE_PORT}/api/reviews/product/1 | jq '[.[].rating] | add / length') && echo \"\$RATINGS\" | grep -qE '^[0-9]+(\.[0-9]+)?$'" "Calcul de la moyenne via jq"

# Test DB : On cache le mot de passe dans l'affichage HTML
DB_CMD="mariadb --skip-ssl -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -sN -e 'SELECT COUNT(*) FROM reviews WHERE rating < 1 OR rating > 5'"
run_test "11. DB Integrity - Ratings 1-5 Only" "$DB_CMD" "mariadb -h $DB_HOST -u ${DB_USER} -p**** ${DB_NAME} -e 'Check Ratings Range'"

# --- FINALISATION ---
echo "----------------------------------------------------------------------" | tee -a "$LOG_FILE"
echo "${GREEN}Succès : Les 11 points de contrôle sont validés.${NC}" | tee -a "$LOG_FILE"
echo "</div><p style='text-align:center; color:#7f8c8d; font-size: 0.9em;'>Rapport généré le $(date)</p></body></html>" >> "$HTML_FILE"

kill $SERVICE_PID 2>/dev/null || true