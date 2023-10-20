/*
Copyright (c) 2021, Hippocrates Technologies S.r.l.. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of the copyright holder(s) nor the names of any contributor(s) may
be used to endorse or promote products derived from this software without specific
prior written permission. No license is granted to the trademarks of the copyright
holders even if such marks are included in this software.

4. Commercial redistribution in any form requires an explicit license agreement with the
copyright holder(s). Please contact support@hippocratestech.com for further information
regarding licensing.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.
 */

import XCTest
import OTFCloudantStore
import OTFCloudClientAPI
import OTFUtilities

class OTFCloudantSSETest: XCTestCase {

    private let testEmail = "<your-test-email>"
    private let testPassword = "<your-test-password>"

    func testSubscribeChange() {
        let timeout: TimeInterval = 3_000.0
        let expect = expectation(description: "This should get an callback in handler \(timeout) seconds, otherwise we will consider this test case failed.")

        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnOpen = {
            OTFLog("**** Event source open...", "")
            do {
                try CloudantSync.shared.replicate(direction: .push, environment: .theraforge) { error in
                    OTFError("PUSH ERROR: %{public}@", error?.localizedDescription ?? "")
                }
            } catch {
                OTFError("Error: %{public}@", error.localizedDescription)
            }
        }

        shared.onReceivedMessage = { event in
            OTFLog("**** Event Recieved -", event.message)
            expect.fulfill()
        }

        login(shared) { result in
            switch result {
            case .success(let response):
                OTFLog("Response: %{public}@", response.message ?? "")
                let auth = Auth(accesstoken: response.token, refreshToken: response.refreshToken)
                shared.observeChangeEvent(auth: auth)
            case .failure(let error):
                OTFError("Error: %{public}@", error.localizedDescription)
            }
        }

        waitForExpectations(timeout: timeout) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testCreateChangeEvent() {
        let timeout: TimeInterval = 3_000
        let expect = expectation(description: "This should get a callback in handler in \(timeout) seconds. otherwise we will consider this test case failed.")

        let shared = TheraForgeNetwork.shared

        shared.eventSourceOnOpen = {
            OTFLog("CREATE EVENT: Event source opened....")
        }

        shared.onReceivedMessage = { event in
            OTFLog("CREATE EVENT: %{public}@", event.message)
            expect.fulfill()
        }

        login(shared) { result in
            switch result {
            case .success(let response):
                OTFLog("Response: %{public}@", response.message ?? "")
                let auth = Auth(accesstoken: response.token, refreshToken: response.refreshToken)
                shared.observeChangeEvent(auth: auth)
            case .failure(let error):
                OTFError("Error: %{public}@", error.localizedDescription)
            }
        }

        waitForExpectations(timeout: timeout) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    private func login(_ shared: TheraForgeNetwork, completion: @escaping(Result<Response.Login, ForgeError>) -> Void) {
        shared.login(request: Request.Login(email: testEmail, password: testPassword), completionHandler: completion)
    }
}
