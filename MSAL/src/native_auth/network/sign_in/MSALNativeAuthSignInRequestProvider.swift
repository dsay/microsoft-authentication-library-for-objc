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

@_implementationOnly import MSAL_Private

protocol MSALNativeAuthSignInRequestProviding {
    func inititate(
        parameters: MSALNativeAuthSignInInitiateRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest

    func challenge(
        parameters: MSALNativeAuthSignInChallengeRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest

    func token(
        parameters: MSALNativeAuthSignInTokenRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest
}

final class MSALNativeAuthSignInRequestProvider: MSALNativeAuthSignInRequestProviding {

    // MARK: - Variables
    private let requestConfigurator: MSALNativeAuthRequestConfigurator
    private let telemetryProvider: MSALNativeAuthTelemetryProviding

    // MARK: - Init

    init(
        requestConfigurator: MSALNativeAuthRequestConfigurator,
        telemetryProvider: MSALNativeAuthTelemetryProviding = MSALNativeAuthTelemetryProvider()
    ) {
        self.requestConfigurator = requestConfigurator
        self.telemetryProvider = telemetryProvider
    }

    // MARK: - SignIn Initiate

    func inititate(
        parameters: MSALNativeAuthSignInInitiateRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .signIn(.initiate(parameters)),
                                          request: request,
                                          telemetryProvider: telemetryProvider)

        return request
    }

    // MARK: - SignIn Challenge

    func challenge(
        parameters: MSALNativeAuthSignInChallengeRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .signIn(.challenge(parameters)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }

    // MARK: - SignIn Token

    func token(
        parameters: MSALNativeAuthSignInTokenRequestParameters,
        context: MSIDRequestContext
    ) throws -> MSIDHttpRequest {

        let request = MSIDHttpRequest()
        try requestConfigurator.configure(configuratorType: .signIn(.token(parameters)),
                                      request: request,
                                      telemetryProvider: telemetryProvider)
        return request
    }
}
