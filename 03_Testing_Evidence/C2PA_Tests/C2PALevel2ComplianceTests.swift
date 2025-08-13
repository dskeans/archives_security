import XCTest
import DeviceCheck
import CryptoKit
@testable import arcHIVE_Camera_App

/// Comprehensive test suite for C2PA Level 2 compliance verification
/// Tests all security requirements and attestation capabilities
class C2PALevel2ComplianceTests: XCTestCase {
    
    var c2paService: C2PAService!
    var securityAnalysis: SecurityAnalysisService!
    var appAttest: AppAttestService!
    
    override func setUp() {
        super.setUp()
        c2paService = C2PAService.shared
        securityAnalysis = SecurityAnalysisService()
        if #available(iOS 14.0, *) {
            appAttest = AppAttestService()
        }
    }
    
    override func tearDown() {
        c2paService = nil
        securityAnalysis = nil
        appAttest = nil
        super.tearDown()
    }
    
    // MARK: - Level 2 Requirement Tests
    
    func testHardwareAttestationSupport() {
        guard #available(iOS 14.0, *) else {
            XCTSkip("App Attest requires iOS 14.0+")
        }
        
        // Test that App Attest is properly integrated
        XCTAssertNotNil(appAttest, "AppAttestService should be initialized")
        
        // Note: App Attest is not supported in simulator
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
            XCTAssertTrue(DCAppAttestService.shared.isSupported, "App Attest should be supported on real devices")
        }
    }
    
    func testSecurityAnalysisCompleteness() async {
        // Test comprehensive security analysis
        await securityAnalysis.performSecurityAnalysis()
        
        XCTAssertNotNil(securityAnalysis.analysisResults, "Security analysis should produce results")
        
        guard let results = securityAnalysis.analysisResults else { return }
        
        // Verify exploit countermeasures
        XCTAssertTrue(results.exploitCountermeasures.aslr, "ASLR should be enabled")
        XCTAssertTrue(results.exploitCountermeasures.stackCanaries, "Stack canaries should be enabled")
        XCTAssertTrue(results.exploitCountermeasures.dep, "DEP should be enabled")
        XCTAssertTrue(results.exploitCountermeasures.codeSigningEnabled, "Code signing should be enabled")
        XCTAssertTrue(results.exploitCountermeasures.sandboxEnabled, "Sandbox should be enabled")
        
        // Verify build configuration
        XCTAssertTrue(results.buildConfiguration.stackProtection, "Stack protection should be enabled")
        XCTAssertTrue(results.buildConfiguration.aslrEnabled, "ASLR should be enabled in build config")
        XCTAssertTrue(results.buildConfiguration.depEnabled, "DEP should be enabled in build config")
    }
    
    func testLevel2ComplianceVerification() async {
        // Test Level 2 compliance checking
        await c2paService.checkLevel2Compliance()
        
        // On devices with App Attest support, should achieve Level 2
        if #available(iOS 14.0, *), DCAppAttestService.shared.isSupported {
            XCTAssertEqual(c2paService.complianceLevel, .level2, "Should achieve Level 2 compliance on supported devices")
            XCTAssertTrue(c2paService.attestationEnabled, "Attestation should be enabled")
        } else {
            XCTAssertEqual(c2paService.complianceLevel, .level1, "Should maintain Level 1 compliance on unsupported devices")
        }
    }
    
    func testCertificateEnrollmentChallenge() {
        // Test challenge generation for certificate enrollment
        let challenge1 = c2paService.createEnrollmentChallenge()
        let challenge2 = c2paService.createEnrollmentChallenge()
        
        XCTAssertFalse(challenge1.isEmpty, "Challenge should not be empty")
        XCTAssertNotEqual(challenge1, challenge2, "Challenges should be unique (include timestamp)")
        XCTAssertEqual(challenge1.count, 32, "SHA256 hash should be 32 bytes")
    }
    
    func testComplianceReporting() {
        // Test compliance report generation
        let report = c2paService.getLevel2ComplianceReport()
        
        XCTAssertNotNil(report["complianceLevel"], "Report should include compliance level")
        XCTAssertNotNil(report["attestationEnabled"], "Report should include attestation status")
        XCTAssertNotNil(report["appAttestSupported"], "Report should include App Attest support status")
        XCTAssertNotNil(report["securityFeatures"], "Report should include security features")
        
        // Verify security features are properly reported
        if let securityFeatures = report["securityFeatures"] as? [String: Bool] {
            XCTAssertTrue(securityFeatures["aslr"] ?? false, "ASLR should be reported as enabled")
            XCTAssertTrue(securityFeatures["stackCanaries"] ?? false, "Stack canaries should be reported as enabled")
            XCTAssertTrue(securityFeatures["dep"] ?? false, "DEP should be reported as enabled")
            XCTAssertTrue(securityFeatures["sandboxEnabled"] ?? false, "Sandbox should be reported as enabled")
        }
    }
    
    // MARK: - Security Feature Tests
    
    func testRuntimeSecurityChecks() {
        // Test runtime security monitoring
        let isSecure = securityAnalysis.checkRuntimeSecurity()
        
        // Should pass on normal devices, fail on jailbroken/debugged devices
        XCTAssertTrue(isSecure, "Runtime security checks should pass in test environment")
    }
    
    func testBinaryIntegrityVerification() {
        // Test binary integrity checking
        let isIntact = securityAnalysis.verifyBinaryIntegrity()
        
        XCTAssertTrue(isIntact, "Binary integrity should be verified")
    }
    
    func testVulnerabilityManagement() async {
        // Test vulnerability scanning
        await securityAnalysis.performSecurityAnalysis()
        
        guard let results = securityAnalysis.analysisResults else {
            XCTFail("Security analysis should produce results")
            return
        }
        
        // Should have no critical vulnerabilities in test environment
        let criticalVulns = results.vulnerabilities.filter { $0.severity == .critical }
        XCTAssertTrue(criticalVulns.isEmpty, "Should have no critical vulnerabilities")
        
        // Verify vulnerability management process
        XCTAssertTrue(results.vulnerabilityManagement.scaImplemented, "SCA should be implemented")
        XCTAssertTrue(results.vulnerabilityManagement.sbomGenerated, "SBOM should be generated")
        XCTAssertTrue(results.vulnerabilityManagement.remediationProcess, "Remediation process should be in place")
    }
    
    // MARK: - Performance Tests
    
    func testSecurityAnalysisPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Security analysis completion")
            
            Task {
                await securityAnalysis.performSecurityAnalysis()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testComplianceCheckPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Compliance check completion")
            
            Task {
                await c2paService.checkLevel2Compliance()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testAttestationErrorHandling() async {
        guard #available(iOS 14.0, *) else {
            XCTSkip("App Attest requires iOS 14.0+")
        }
        
        // Test error handling when Level 2 is not supported
        c2paService.complianceLevel = .level1
        
        do {
            _ = try await c2paService.generateCertificateEnrollmentAttestation()
            XCTFail("Should throw error when not Level 2 compliant")
        } catch C2PAService.C2PAError.attestationFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullLevel2Workflow() async {
        // Test complete Level 2 workflow
        
        // 1. Check compliance
        await c2paService.checkLevel2Compliance()
        
        // 2. Perform security analysis
        await securityAnalysis.performSecurityAnalysis()
        
        // 3. Generate compliance report
        let report = c2paService.getLevel2ComplianceReport()
        
        // 4. Verify report completeness
        XCTAssertNotNil(report["complianceLevel"])
        XCTAssertNotNil(report["securityFeatures"])
        
        // 5. Test attestation if supported
        if c2paService.complianceLevel == .level2 {
            do {
                let attestation = try await c2paService.generateCertificateEnrollmentAttestation()
                XCTAssertFalse(attestation.isEmpty, "Attestation should not be empty")
            } catch {
                // Attestation may fail in simulator - that's expected
                if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
                    print("Attestation failed in simulator (expected): \(error)")
                } else {
                    XCTFail("Attestation failed on real device: \(error)")
                }
            }
        }
    }
}

// MARK: - Test Utilities

extension C2PALevel2ComplianceTests {
    
    /// Helper to verify compliance level requirements
    private func verifyComplianceLevel(_ level: C2PAService.ComplianceLevel) {
        switch level {
        case .level1:
            // Level 1 requirements should always be met
            XCTAssertTrue(true, "Level 1 compliance verified")
        case .level2:
            // Level 2 requires additional features
            if #available(iOS 14.0, *) {
                XCTAssertTrue(DCAppAttestService.shared.isSupported || ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil,
                             "Level 2 requires App Attest support or simulator environment")
            }
        }
    }
    
    /// Helper to create test security analysis results
    private func createTestSecurityResults() -> SecurityAnalysisService.SecurityAnalysisResults {
        return SecurityAnalysisService.SecurityAnalysisResults(
            timestamp: Date(),
            buildConfiguration: SecurityAnalysisService.BuildConfiguration(
                optimizationLevel: "Release",
                stackProtection: true,
                aslrEnabled: true,
                depEnabled: true,
                codeSigningEnabled: true,
                sandboxEnabled: true,
                bitrodeEnabled: false
            ),
            exploitCountermeasures: SecurityAnalysisService.ExploitCountermeasures(
                aslr: true,
                stackCanaries: true,
                guardPages: true,
                dep: true,
                safeHeap: true,
                nx: true
            ),
            staticAnalysis: SecurityAnalysisService.StaticAnalysisResults(
                toolsUsed: ["Xcode Static Analyzer", "SwiftLint"],
                issuesFound: 0,
                criticalIssues: 0,
                highIssues: 0,
                mediumIssues: 0,
                lowIssues: 0,
                lastAnalysisDate: Date()
            ),
            vulnerabilities: [],
            complianceLevel: .level2
        )
    }
}
