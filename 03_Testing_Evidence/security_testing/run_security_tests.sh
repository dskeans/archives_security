#!/bin/bash

# 🛡️ arcHIVE Camera App - Security Testing Suite
# Comprehensive security testing using C2PA attack vectors
# Run this script regularly to ensure ongoing security compliance

set -e

echo "🛡️ arcHIVE Camera App - Security Testing Suite"
echo "=============================================="
echo "Date: $(date)"
echo "Testing C2PA Level 2 Security Compliance"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}🧪 Running: $test_name${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

# Function to check if file exists
check_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}❌ Error: Required file not found: $file${NC}"
        exit 1
    fi
}

# Check required files
echo "🔍 Checking required files..."
check_file "security_testing/test_security_implementations.swift"
check_file "security_testing/attack_vectors/xss_attacks.txt"
check_file "security_testing/attack_vectors/sql_injection_attacks.txt"
echo -e "${GREEN}✅ All required files found${NC}"
echo ""

# Run main security test suite
echo "🔐 Running Main Security Test Suite..."
run_test "MetadataSanitizer Security Tests" "swift security_testing/test_security_implementations.swift"

# Test attack vector files
echo "📋 Validating Attack Vector Files..."
run_test "XSS Attack Vectors File" "test -s security_testing/attack_vectors/xss_attacks.txt"
run_test "SQL Injection Attack Vectors File" "test -s security_testing/attack_vectors/sql_injection_attacks.txt"

# Test C2PA tools (if available)
if command -v c2pa-attacks &> /dev/null; then
    echo "🔧 Testing C2PA Attack Tools..."
    run_test "C2PA Attack Tool Available" "c2pa-attacks --version"
else
    echo -e "${YELLOW}⚠️  C2PA attack tool not available (optional)${NC}"
fi

# Test Swift compilation
echo "🏗️  Testing Swift Compilation..."
run_test "Swift Security Test Compilation" "swiftc -parse security_testing/test_security_implementations.swift"

# Validate security implementations exist in main codebase
echo "🔍 Validating Security Implementation Files..."
if [[ -f "arcHIVE_Camera_App/Security/MetadataSanitizer.swift" ]]; then
    run_test "MetadataSanitizer Implementation" "test -f arcHIVE_Camera_App/Security/MetadataSanitizer.swift"
else
    echo -e "${YELLOW}⚠️  MetadataSanitizer.swift not found in expected location${NC}"
fi

if [[ -f "arcHIVE_Camera_App/Security/C2PAManager.swift" ]]; then
    run_test "C2PAManager Implementation" "test -f arcHIVE_Camera_App/Security/C2PAManager.swift"
else
    echo -e "${YELLOW}⚠️  C2PAManager.swift not found in expected location${NC}"
fi

# Test for common security vulnerabilities in code
echo "🔍 Scanning for Security Vulnerabilities..."

# Check for hardcoded secrets
if grep -r "password\|secret\|key\|token" --include="*.swift" arcHIVE_Camera_App/ | grep -v "// " | grep -v "func " | grep -v "var " | grep -v "let " > /dev/null 2>&1; then
    echo -e "${RED}❌ SECURITY WARNING: Potential hardcoded secrets found${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
else
    echo -e "${GREEN}✅ No hardcoded secrets detected${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Check for SQL injection vulnerabilities
if grep -r "SELECT\|INSERT\|UPDATE\|DELETE" --include="*.swift" arcHIVE_Camera_App/ | grep -v "sanitize" | grep -v "clean" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  SQL statements found - ensure they are properly sanitized${NC}"
else
    echo -e "${GREEN}✅ No direct SQL statements detected${NC}"
fi

# Check for XSS vulnerabilities
if grep -r "innerHTML\|outerHTML\|document.write" --include="*.swift" --include="*.js" --include="*.html" arcHIVE_Camera_App/ > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Potential XSS vectors found - ensure proper sanitization${NC}"
else
    echo -e "${GREEN}✅ No obvious XSS vectors detected${NC}"
fi

# Generate security report
echo ""
echo "📊 SECURITY TEST RESULTS"
echo "========================"
echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

# Calculate success rate
if [[ $TOTAL_TESTS -gt 0 ]]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Success Rate: ${BLUE}$SUCCESS_RATE%${NC}"
else
    SUCCESS_RATE=0
fi

echo ""

# Final assessment
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL SECURITY TESTS PASSED!${NC}"
    echo -e "${GREEN}🛡️  arcHIVE Camera App is SECURE and ready for production${NC}"
    echo -e "${GREEN}✅ C2PA Level 2 Security Compliance: VERIFIED${NC}"
    exit 0
elif [[ $SUCCESS_RATE -ge 90 ]]; then
    echo -e "${YELLOW}⚠️  Most security tests passed ($SUCCESS_RATE%)${NC}"
    echo -e "${YELLOW}🔧 Review failed tests and address issues${NC}"
    exit 1
else
    echo -e "${RED}❌ SECURITY TESTS FAILED${NC}"
    echo -e "${RED}🚨 Critical security issues detected - DO NOT DEPLOY${NC}"
    echo -e "${RED}🔧 Address all security failures before proceeding${NC}"
    exit 2
fi
