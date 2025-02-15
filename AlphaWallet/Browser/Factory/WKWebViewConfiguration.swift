// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import WebKit
import JavaScriptCore

enum WebViewType {
    case dappBrowser(RPCServer)
    case tokenScriptRenderer
}

extension WKWebViewConfiguration {

    static func make(forType type: WebViewType, address: AlphaWallet.Address, in messageHandler: WKScriptMessageHandler) -> WKWebViewConfiguration {
        let webViewConfig = WKWebViewConfiguration()
        var js = ""

        switch type {
        case .dappBrowser(let server):
            guard
                    let bundlePath = Bundle.main.path(forResource: "AlphaWalletWeb3Provider", ofType: "bundle"),
                    let bundle = Bundle(path: bundlePath) else { return webViewConfig }
            if let filepath = bundle.path(forResource: "AlphaWallet-min", ofType: "js") {
                do {
                    js += try String(contentsOfFile: filepath)
                } catch { }
            }
            js += javaScriptForDappBrowser(server: server, address: address)
        case .tokenScriptRenderer:
            js += javaScriptForTokenScriptRenderer(address: address)
            js += """
                  \n
                  web3.tokens = {
                      data: {
                          currentInstance: {
                          },
                          token: {
                          },
                          card: {
                          },
                      },
                      dataChanged: (old, updated, tokenCardId) => {
                        console.log(\"web3.tokens.data changed. You should assign a function to `web3.tokens.dataChanged` to monitor for changes like this:\\n    `web3.tokens.dataChanged = (old, updated, tokenCardId) => { //do something }`\")
                      }
                  }
                  """
        }
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webViewConfig.userContentController.addUserScript(userScript)

        switch type {
        case .dappBrowser:
            break
        case .tokenScriptRenderer:
            //TODO enable content blocking rules to support whitelisting
            webViewConfig.setURLSchemeHandler(webViewConfig, forURLScheme: "tokenscript-resource")
        }

        webViewConfig.userContentController.add(messageHandler, name: Method.signTransaction.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signPersonalMessage.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signMessage.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signTypedMessage.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.ethCall.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: WalletCommand.Method.walletAddEthereumChain.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: BrowserViewController.locationChangedEventName)
        //TODO extract like `Method.signTypedMessage.rawValue` when we have more than 1
        webViewConfig.userContentController.add(messageHandler, name: TokenInstanceWebView.SetProperties.setActionProps)
        return webViewConfig
    }

    fileprivate static func javaScriptForDappBrowser(server: RPCServer, address: AlphaWallet.Address) -> String {
        return """
               //Space is needed here because it is sometimes cut off by websites. 
               
               const addressHex = "\(address.eip55String)"
               const rpcURL = "\(server.rpcURL.absoluteString)"
               const chainID = "\(server.chainID)"

               function executeCallback (id, error, value) {
                   AlphaWallet.executeCallback(id, error, value)
               }

               AlphaWallet.init(rpcURL, {
                   getAccounts: function (cb) { cb(null, [addressHex]) },
                   processTransaction: function (tx, cb){
                       console.log('signing a transaction', tx)
                       const { id = 8888 } = tx
                       AlphaWallet.addCallback(id, cb)
                       webkit.messageHandlers.signTransaction.postMessage({"name": "signTransaction", "object":     tx, id: id})
                   },
                   signMessage: function (msgParams, cb) {
                       const { data } = msgParams
                       const { id = 8888 } = msgParams
                       console.log("signing a message", msgParams)
                       AlphaWallet.addCallback(id, cb)
                       webkit.messageHandlers.signMessage.postMessage({"name": "signMessage", "object": { data }, id:    id} )
                   },
                   signPersonalMessage: function (msgParams, cb) {
                       const { data } = msgParams
                       const { id = 8888 } = msgParams
                       console.log("signing a personal message", msgParams)
                       AlphaWallet.addCallback(id, cb)
                       webkit.messageHandlers.signPersonalMessage.postMessage({"name": "signPersonalMessage", "object":  { data }, id: id})
                   },
                   signTypedMessage: function (msgParams, cb) {
                       const { data } = msgParams
                       const { id = 8888 } = msgParams
                       console.log("signing a typed message", msgParams)
                       AlphaWallet.addCallback(id, cb)
                       webkit.messageHandlers.signTypedMessage.postMessage({"name": "signTypedMessage", "object":     { data }, id: id})
                   },
                   ethCall: function (msgParams, cb) {
                       const data = msgParams
                       const { id = Math.floor((Math.random() * 100000) + 1) } = msgParams
                       console.log("eth_call", msgParams)
                       AlphaWallet.addCallback(id, cb)
                       webkit.messageHandlers.ethCall.postMessage({"name": "ethCall", "object": data, id: id})
                   },
                   walletAddEthereumChain: function (msgParams, cb) {
                       const data = msgParams
                       const { id = Math.floor((Math.random() * 100000) + 1) } = msgParams
                       console.log("walletAddEthereumChain", msgParams)
                       AlphaWallet.addCallback(id, cb)
                       webkit.messageHandlers.walletAddEthereumChain.postMessage({"name": "walletAddEthereumChain", "object": data, id: id})
                   },
                   enable: function() {
                      return new Promise(function(resolve, reject) {
                          //send back the coinbase account as an array of one
                          resolve([addressHex])
                      })
                   }
               }, {
                   address: addressHex,
                   networkVersion: "0x" + parseInt(chainID).toString(16) || null
               })

               web3.setProvider = function () {
                   console.debug('AlphaWallet Wallet - overrode web3.setProvider')
               }

               web3.eth.defaultAccount = addressHex

               web3.version.getNetwork = function(cb) {
                   cb(null, chainID)
               }

              web3.eth.getCoinbase = function(cb) {
               return cb(null, addressHex)
             }
             window.ethereum = web3.currentProvider
               
             // So we can detect when sites use History API to generate the page location. Especially common with React and similar frameworks
             ;(function() {
               var pushState = history.pushState;
               var replaceState = history.replaceState;

               history.pushState = function() {
                 pushState.apply(history, arguments);
                 window.dispatchEvent(new Event('locationchange'));
               };

               history.replaceState = function() {
                 replaceState.apply(history, arguments);
                 window.dispatchEvent(new Event('locationchange'));
               };

               window.addEventListener('popstate', function() {
                 window.dispatchEvent(new Event('locationchange'))
               });
             })();

             window.addEventListener('locationchange', function(){
               webkit.messageHandlers.\(BrowserViewController.locationChangedEventName).postMessage(window.location.href)
             })
             """
    }

    fileprivate static func javaScriptForTokenScriptRenderer(address: AlphaWallet.Address) -> String {
        return """
               window.web3CallBacks = {}
               window.tokenScriptCallBacks = {}

               function executeCallback (id, error, value) {
                   window.web3CallBacks[id](error, value)
                   delete window.web3CallBacks[id]
               }

               function executeTokenScriptCallback (id, error, value) {
                   let cb = window.tokenScriptCallBacks[id]
                   if (cb) {
                       window.tokenScriptCallBacks[id](error, value)
                       delete window.tokenScriptCallBacks[id]
                   } else {
                   }
               }

               web3 = {
                 personal: {
                   sign: function (msgParams, cb) {
                     const { data } = msgParams
                     const { id = 8888 } = msgParams
                     window.web3CallBacks[id] = cb
                     webkit.messageHandlers.signPersonalMessage.postMessage({"name": "signPersonalMessage", "object":  { data }, id: id})
                   }
                 },
                 action: {
                   setProps: function (object, cb) {
                     const id = 8888
                     window.tokenScriptCallBacks[id] = cb
                     webkit.messageHandlers.\(TokenInstanceWebView.SetProperties.setActionProps).postMessage({"object":  object, id: id})
                   }
                 }
               }
               """
    }

    fileprivate static func contentBlockingRulesJson() -> String {
        //TODO read from TokenScript, when it's designed and available
        let whiteListedUrls = [
            "https://unpkg.com/",
            "^tokenscript-resource://",
            "^http://stormbird.duckdns.org:8080/api/getChallenge$",
            "^http://stormbird.duckdns.org:8080/api/checkSignature"
        ]
        //Blocks everything, except the whitelisted URL patterns
        var json = """
                   [
                       {
                           "trigger": {
                               "url-filter": ".*"
                           },
                           "action": {
                               "type": "block"
                           }
                       }
                   """
        for each in whiteListedUrls {
            json += """
                    ,
                    {
                        "trigger": {
                            "url-filter": "\(each)"
                        },
                        "action": {
                            "type": "ignore-previous-rules"
                        }
                    }
                    """
        }
        json += "]"
        return json
    }
}

extension WKWebViewConfiguration: WKURLSchemeHandler {
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if urlSchemeTask.request.url?.path != nil {
            if let fileExtension = urlSchemeTask.request.url?.pathExtension, fileExtension == "otf", let nameWithoutExtension = urlSchemeTask.request.url?.deletingPathExtension().lastPathComponent {
                //TODO maybe good to fail with didFailWithError(error:)
                guard let url = Bundle.main.url(forResource: nameWithoutExtension, withExtension: fileExtension) else { return }
                guard let data = try? Data(contentsOf: url) else { return }
                //mimeType doesn't matter. Blocking is done based on how browser intends to use it
                let response = URLResponse(url: urlSchemeTask.request.url!, mimeType: "font/opentype", expectedContentLength: data.count, textEncodingName: nil)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
                return
            }
        }
        //TODO maybe good to fail:
        //urlSchemeTask.didFailWithError(error:)
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        //Do nothing
    }
}
