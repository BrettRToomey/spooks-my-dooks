import HTTP
import Vapor
import Dispatch
import Foundation

let queue = DispatchQueue(label: "spooky.worker")

public struct SlackCredentials {
    let token: String
    let simpleLatest: Bool
    let noUnreads: Bool
    
    public init(token: String, simpleLatest: Bool = true, noUnreads: Bool = true) {
        self.token = token
        self.simpleLatest = simpleLatest
        self.noUnreads = noUnreads
    }
}

public enum Reaction: String {
    case ghost
    case x
    case disappointed
    case see_no_evil
    case sunglasses
    case cat2
    case yay
    case rage
}

public func startSession(_ credentials: SlackCredentials) throws -> Response {
    let headers: [HeaderKey: String] = ["Accept": "application/json; charset=utf-8"]
    let query: [String: NodeRepresentable] = [
        "token": credentials.token,
        "simple_latest": credentials.simpleLatest ? 1 : 0,
        "no_unreads": credentials.noUnreads ? 1 : 0
    ]
    
    return try EngineClient.factory.get(
        "https://slack.com/api/rtm.start",
        query: query,
        headers
    )
}

@discardableResult
public func sendMessage(_ ws: WebSocket, message: String, channel: String, id: UInt32? = nil) throws -> UInt32 {
    let id = id ?? UInt32.random()
    
    var response = JSON()
    try response.set("id", id)
    try response.set("channel", channel)
    try response.set("type", "message")
    try response.set("text", message)
    
    try ws.send(response.makeBytes().makeString())
    return id
}

public func deleteMessage(_ ws: WebSocket, credentials: SlackCredentials, channel: String, timestamp: String, timeout: TimeInterval) throws {
    let headers: [HeaderKey: String] = ["Accept": "application/json; charset=utf-8"]
    let query: [String: NodeRepresentable] = [
        "token": credentials.token,
        "ts": timestamp,
        "channel": channel,
        "as_user": true
    ]
    
    queue.asyncAfter(deadline: .now() + timeout) {
        do {
            _ = try EngineClient.factory.post(
                "https://slack.com/api/chat.delete",
                query: query,
                headers
            )
        } catch {
            print("Failed to delete message: \(error)")
        }
    }
}

public func addReaction(ws: WebSocket, credentials: SlackCredentials, channel: String, timestamp: String, reaction: Reaction) throws {
    let headers: [HeaderKey: String] = ["Accept": "application/json; charset=utf-8"]
    let query: [String: NodeRepresentable] = [
        "token": credentials.token,
        "timestamp": timestamp,
        "channel": channel,
        "name": reaction.rawValue
    ]
    
    _ = try EngineClient.factory.post(
        "https://slack.com/api/reactions.add",
        query: query,
        headers
    )
}

public func join(ws: WebSocket, credentials: SlackCredentials, channel: String) throws {
    let headers: [HeaderKey: String] = ["Accept": "application/json; charset=utf-8"]
    let query: [String: NodeRepresentable] = [
        "token": credentials.token,
        "channel": channel
    ]
    
    _ = try EngineClient.factory.post(
        "https://slack.com/api/channels.join",
        query: query,
        headers
    )
}
