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

import Foundation
import OTFUtilities

public enum RequestMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public class OTFNetwork {
    public static var shared = OTFNetwork()
    private var baseURL = ""
    private let session = URLSession.shared

    private init() {}

    public func setBaseUrl(baseURL: String) {
        self.baseURL = baseURL
    }

    /**
       To make a networking call with URLRequest Parameter, it with return a completionHandler with Data and Error objects.
    */
    public func sendRequest(urlRequest: URLRequest, completionBlOTF: @escaping (Result<Data, Error>) -> Void) {
        session.dataTask(with: urlRequest) { (data, urlResponse, error) in
            DispatchQueue.main.async {
                if let urlResponse = urlResponse {
                    OTFLog("URL description %{public}@", urlResponse.description)
                }
                if let error = error {
                    completionBlOTF(.failure(error))
                    return
                }
                if let data = data {
                    OTFLog("Data responded: %{public}@", String(data: data, encoding: .utf8) ?? "Request successful with result: nil")
                    completionBlOTF(.success(data))
                }
            }
        }.resume()
    }

    /**
        To make a network call with URLRequest Parameter, it will return a completionHandler with confirming generic data type and an Error.
     */
    public func sendJsonResultRequest<T: Decodable>(urlRequest: URLRequest, result: @escaping (Result<T, Error>) -> Void) {
        sendRequest(urlRequest: urlRequest) { (response) in
            switch response {
            case .success(let data):
                do {
                    let model = try JSONDecoder().decode(T.self, from: data)
                    result(.success(model))
                } catch let error {
                    OTFError("Decode failed with error: %{public}@", error.localizedDescription)
                    result(.failure(error))
                }
            case .failure(let error):
                result(.failure(error))
            }
        }
    }

    /**
        - Description: To make a networking call with givne endpoint, parameters, headers nad request HTTP method type.
        - Parameter endpoint: endpoint of your api call
        - Parameter params: Parameter of your api call if required. It is an option value, so you can also pass nil in it.
        - Parameter headers: Header dictionary if required by API. it is an optional value, so  you can pass nil in it.
        - Parameter method: HTTP method type (get, post, put, delete). We have provided custom enum for these requests so you can select from them.
        - Parameter completionBlOTF : Completion handler for this API call, it will return a result of of generic data type and an error object in it.
     */
    public func sendRequest<T: Decodable>(endpoint: String, params: [String: String]?, headers: [String: String]?, method: RequestMethod, completionBlOTF: ((Result<T, Error>) -> Void)?) {
        let requestUrlString = "\(baseURL)\(endpoint)"
        var request = URLRequest(url: URL(string: requestUrlString)!)
        if method == .get {
            if let params = params {
                request = URLRequest(url: URL(string: requestUrlString + buildQueryString(fromDictionary: params))!)
            }
        }
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        sendJsonResultRequest(urlRequest: request) { (res: Result<T, Error>) in
            switch res {
            case .success(let data):
                completionBlOTF?(.success(data))
            case .failure(let error):
                completionBlOTF?(.failure(error))
            }
        }
    }

    public func buildQueryString(fromDictionary parameters: [String: String]) -> String {
        var urlVars: [String] = []
        for (key, value) in parameters {
            let encodedValue = value.addPercentEncoding()
            urlVars.append(key + "=" + encodedValue)
        }

        return urlVars.isEmpty ? "" : "?" + urlVars.joined(separator: "&")
    }

}

extension URLRequest {

    /**
     Returns a cURL command representation of this URL request.
     */
    public var curlString: String {
        guard let url = url else { return "" }
        var baseCommand = #"curl "\#(url.absoluteString)""#

        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }

        var command = [baseCommand]

        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }

        if let headers = allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }

        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }

        return command.joined(separator: " \\\n\t")
    }

}
