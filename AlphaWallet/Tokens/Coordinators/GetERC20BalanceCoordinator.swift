// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Result
import web3swift
import PromiseKit

class GetERC20BalanceCoordinator: CallbackQueueProvider {
    private let server: RPCServer
    internal let queue: DispatchQueue?

    init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }
    
    func getBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<BigInt> {
        return Promise { seal in
            getBalance(for: address, contract: contract) { result in
                switch result {
                case .success(let value):
                    seal.fulfill(value)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getBalance(
            for address: AlphaWallet.Address,
            contract: AlphaWallet.Address,
            completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void
    ) {
        let functionName = "balanceOf"
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI, parameters: [address.eip55String] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout).done(on: queue, { balanceResult in
            if let balanceWithUnknownType = balanceResult["0"] {
                let string = String(describing: balanceWithUnknownType)
                if let balance = BigInt(string) {
                    completion(.success(balance))
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
                }
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
            }
        }).catch(on: queue, {
            completion(.failure(AnyError($0)))
        })
    }
}
