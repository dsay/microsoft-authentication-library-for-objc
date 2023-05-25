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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

@objc
public protocol SignInCompletedDelegate {
    func onSignInCompleted(result: MSALNativeAuthUserAccount)
}

@objc
public protocol SignInPasswordStartDelegate: SignInCompletedDelegate {
    func onSignInError(error: SignInPasswordStartError)
    @objc optional func onSignInCodeRequired(newState: SignInCodeSentState,
                                             sentTo: String,
                                             channelTargetType: MSALNativeAuthChannelType,
                                             codeLength: Int)
}

@objc
public protocol SignInCodeStartDelegate {
    func onSignInCodeError(error: SignInCodeStartError)
    func onSignInCodeRequired(newState: SignInCodeSentState,
                              sentTo: String,
                              channelTargetType: MSALNativeAuthChannelType,
                              codeLength: Int)
    @objc optional func onSignInPasswordRequired(newState: SignInPasswordRequiredState)
}

@objc
public protocol SignInPasswordRequiredDelegate: SignInCompletedDelegate {
    func onSignInPasswordRequiredError(error: PasswordRequiredError, newState: SignInPasswordRequiredState?)
    @objc optional func onSignInCodeRequired(newState: SignInCodeSentState,
                                             sentTo: String,
                                             channelTargetType: MSALNativeAuthChannelType,
                                             codeLength: Int)
}

@objc
public protocol SignInResendCodeDelegate {
    func onSignInResendCodeError(error: MSALNativeAuthGenericError, newState: SignInCodeSentState?)
    func onSignInResendCodeCodeRequired(newState: SignInCodeSentState,
                                        sentTo: String,
                                        channelTargetType: MSALNativeAuthChannelType,
                                        codeLength: Int)
}

@objc
public protocol SignInVerifyCodeDelegate: SignInCompletedDelegate {
    func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeSentState?)
}
