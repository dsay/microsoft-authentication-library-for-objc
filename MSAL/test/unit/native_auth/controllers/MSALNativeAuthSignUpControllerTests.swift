//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

final class MSALNativeAuthSignUpControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthSignUpController!
    private var contextMock: MSALNativeAuthRequestContext!
    private var requestProviderMock: MSALNativeAuthSignUpRequestProviderMock!
    private var validatorMock: MSALNativeAuthSignUpResponseValidatorMock!
    private var signInControllerMock: MSALNativeAuthSignInControllerMock!

    private var signUpStartPasswordParams: MSALNativeAuthSignUpStartRequestProviderParameters {
        .init(
            username: "user@contoso.com",
            password: "password",
            attributes: ["key": "value"],
            context: contextMock
        )
    }

    private var signUpStartCodeParams: MSALNativeAuthSignUpStartRequestProviderParameters {
        .init(
            username: "user@contoso.com",
            password: nil,
            attributes: ["key": "value"],
            context: contextMock
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        contextMock = .init(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        requestProviderMock = .init()
        validatorMock = .init()
        signInControllerMock = .init()

        sut = MSALNativeAuthSignUpController(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseValidator: validatorMock,
            signInController: signInControllerMock
        )
    }

    // MARK: - SignUpPasswordStart (/start request) tests

    func test_whenSignUpStartPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returnsVerificationRequired_it_callsChallenge() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: prepareSignUpPasswordStartDelegateSpy())
        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returnsAttributeValidationFailed_it_callsChallenge() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesInvalidCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.attributeNames, invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }
    
    func test_whenSignUpStartPassword_returns_InvalidAttributes_but_developerDoesnNotImplementDelegate_it_callsDelegateError() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)
        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let error : MSALNativeAuthSignUpStartValidatedResponse = .error(
            MSALNativeAuthSignUpStartResponseError(error: .passwordTooLong,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(error)
        
        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)
        
        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)
        
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
        
        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returns_invalidUsername_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let invalidUsername : MSALNativeAuthSignUpStartValidatedResponse = .invalidUsername(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidUsername)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartPassword_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpPasswordStart (/challenge request) tests

    func test_whenSignUpStartPassword_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_succeeds_it_callsDelegate() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "signUpToken 2")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: true)
    }

    func test_whenSignUpStartPassword_challenge_returns_succeedPassword_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken,
                                                       errorDescription: "Expired Token",
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, "Expired Token")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartPassword_challenge_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/start request) tests

    func test_whenSignUpStartCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returnsVerificationRequired_it_callsChallenge() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: prepareSignUpCodeStartDelegateSpy())
        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returnsAttributeValidationFailed_it_callsDelegateError() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesInvalidCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.attributeNames ,invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }
    
    func test_whenSignUpStartCode_returns_InvalidAttributes_but_developerDoesnNotImplementDelegate_it_callsDelegateError() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)
        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let error : MSALNativeAuthSignUpStartValidatedResponse = .error(
            MSALNativeAuthSignUpStartResponseError(error: .userAlreadyExists,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .userAlreadyExists)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returns_invalidUsername_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let invalidUsername : MSALNativeAuthSignUpStartValidatedResponse = .invalidUsername(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidUsername)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartCode_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/challenge request) tests

    func test_whenSignUpStartCode_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_succeeds_it_callsDelegate() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken 1", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 1")
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "signUpToken 2")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: true)
    }

    func test_whenSignUpStartCode_challenge_succeedsPassword_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken,
                                                       errorDescription: "Expired Token",
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, "Expired Token")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartCode_challenge_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - ResendCode tests

    func test_whenSignUpResendCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken", delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNotNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken", delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "signUpToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: true)
    }

    func test_whenSignUpResendCode_succeedsPassword_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("signUpToken 1"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken 2", delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNotNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .invalidRequest,
                                                       errorDescription: nil,
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken", delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNotNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken", delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNotNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken", delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNotNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    // MARK: - SubmitCode tests

    func test_whenSignUpSubmitCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSubmitCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.success(""))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCompletedCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_invalidUserInput_it_callsDelegateInvalidCode() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidOOBValue,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertEqual(delegate.newCodeRequiredState?.flowToken, "signUpToken")
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .invalidCode)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_it_callsDelegateAttributesRequired() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken", requiredAttributes: []))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(delegate.newAttributesRequiredState?.flowToken, "signUpToken")
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_but_developerDoesnNotImplementDelegate_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "", requiredAttributes: []))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_attributeValidationFailed_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(signUpToken: "signUpToken 2", invalidAttributes: ["name"]))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitCode + credential_required error tests

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andCantCreateRequest() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andSucceeds() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("signUpToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertEqual(delegate.newPasswordRequiredState?.flowToken, "signUpToken 3")
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andSucceeds_butUserHasNotImplementedOptionalProtocol() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired(""))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andSucceedOOB_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("", .email, 4, "signUpToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andRedirects() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andReturnsError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken,
                                                       errorDescription: nil,
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andReturnsUnexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitPassword tests

    func test_whenSignUpSubmitPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSubmitPassword_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.success("signInSLT"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCompletedCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_invalidUserInput_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .passwordTooWeak,
                                                      errorDescription: "Password too weak",
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertEqual(delegate.newPasswordRequiredState?.flowToken, "signUpToken")
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
        XCTAssertEqual(delegate.error?.errorDescription, "Password too weak")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken 2", requiredAttributes: []))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(delegate.newAttributesRequiredState?.flowToken, "signUpToken 2")
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_it_callsDelegateError_butDeveloperHasNotImplementedOptionalDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken 2", requiredAttributes: []))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_credentialRequired_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_attributeValidationFailed_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(signUpToken: "signUpToken 2", invalidAttributes: ["key"]))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        
        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    // MARK: - SubmitAttributes tests

    func test_whenSignUpSubmitAttributes_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSubmitAttributes_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.success(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCompletedCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: true)
    }

    func test_whenSignUpSubmitAttributes_returns_invalidUserInput_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .attributeValidationFailed,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_attributesRequired_it_callsAttributesRequiredError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken 2", requiredAttributes: []))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "signUpToken 2")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_credentialRequired_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_attributeValidationFailed_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(signUpToken: "signUpToken 2", invalidAttributes: ["key"]))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "signUpToken 2")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    // MARK: - Sign-in with SLT

    func test_whenSignUpSucceeds_and_userCallsSignInWithSLT_signUpControllerPassesCorrectParams() async {
        let username = "username"
        let slt = "signInSLT"

        class SignInAfterSignUpDelegateStub: SignInAfterSignUpDelegate {
            func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {}
            func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {}
        }

        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.success(slt))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("password", username: username, signUpToken: "signUpToken", context: contextMock, delegate: delegate)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCompletedCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)

        let exp2 = expectation(description: "SignInAfterSignUp expectation")
        signInControllerMock.expectation = exp2
        delegate.signInAfterSignUpState?.signIn(delegate: SignInAfterSignUpDelegateStub())
        await fulfillment(of: [exp2], timeout: 1)

        XCTAssertEqual(signInControllerMock.username, username)
        XCTAssertEqual(signInControllerMock.slt, slt)
    }

    // MARK: - Common Methods

    private func checkTelemetryEventResult(id: MSALNativeAuthTelemetryApiId, isSuccessful: Bool) {
        XCTAssertEqual(receivedEvents.count, 1)

        guard let telemetryEventDict = receivedEvents.first else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(id.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event" )
        XCTAssertEqual(telemetryEventDict["correlation_id" ] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, isSuccessful ? "yes" : "no")
        XCTAssertEqual(telemetryEventDict["status"] as? String, isSuccessful ? "succeeded" : "failed")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
    }

    private func prepareSignUpPasswordStartDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpPasswordStartDelegateSpy {
        let delegate = SignUpPasswordStartDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpPasswordErrorCalled)
        XCTAssertFalse(delegate.onSignUpCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpCodeStartDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpCodeStartDelegateSpy {
        let delegate = SignUpCodeStartDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCodeErrorCalled)
        XCTAssertFalse(delegate.onSignUpCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpResendCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpResendCodeDelegateSpy {
        let delegate = SignUpResendCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertFalse(delegate.onSignUpResendCodeCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpSubmitCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpVerifyCodeDelegateSpy {
        let delegate = SignUpVerifyCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCompletedCalled)
        XCTAssertFalse(delegate.onSignUpPasswordRequiredCalled)
        XCTAssertFalse(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertFalse(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpSubmitPasswordDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpPasswordRequiredDelegateSpy {
        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCompletedCalled)
        XCTAssertFalse(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertFalse(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpSubmitAttributesDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpAttributesRequiredDelegateSpy {
        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCompletedCalled)
        XCTAssertFalse(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareMockRequest() -> MSIDHttpRequest {
        let request = MSIDHttpRequest()
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        return request
    }

    private func expectedChallengeParams(token: String = "signUpToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }

    private func expectedContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "signUpToken",
        password: String? = nil,
        oobCode: String? = "1234",
        attributes: [String: Any]? = nil
    ) -> MSALNativeAuthSignUpContinueRequestProviderParams {
        .init(
            grantType: grantType,
            signUpToken: token,
            password: password,
            oobCode: oobCode,
            attributes: attributes,
            context: contextMock
        )
    }
}
