import App
import Vapor
import Foundation

enum FuckMe: Error {
    case invalidAuthentication
}

let config = try Config()
try config.setup()

let me = "@U5WHRCGA3"
let meTagged = "<\(me)>"
let chance = 100 // 1 in 100
let credentials = SlackCredentials(token: "xoxb-200603424343-TilHOQummmK8YlVbnmnkHvr0")
let rtmResponse = try startSession(credentials)

guard let url = rtmResponse.data["url"]?.string else {
    throw FuckMe.invalidAuthentication
}

let lock = NSLock()
var outgoingMessages: [UInt32: String] = [:]

try EngineClient.factory.socket.connect(to: url) { ws in
    ws.onText = { ws, text in
        let event = try JSON(bytes: text.utf8.array)
        
        if let replyId = event["reply_to"]?.int {
            let replyId = UInt32(replyId)
            
            lock.lock()
            defer {
                outgoingMessages.removeValue(forKey: replyId)
                lock.unlock()
            }

            if
                let timestamp = event["ts"]?.string,
                let ok = event["ok"]?.bool,
                ok == true,
                let chan = outgoingMessages[replyId]
            {
                try deleteMessage(ws, credentials: credentials, channel: chan, timestamp: timestamp)
            }
            
            return
        }
        
        guard
            let chan = event["channel"]?.string,
            var message = event["text"]?.string,
            let fromId = event["user"]?.string,
            let timestamp = event["ts"].flatMap({ $0.string.flatMap({ Double($0) }) })
        else {
            return
        }
        
        message = message.trimmingCharacters(in: .whitespaces)
        
        let roll = Int.random(min: 1, max: chance)
        guard message.hasPrefix(meTagged) || roll == chance else { return }
        
        let messageId = try sendMessage(ws, message: "Boooo~~~", channel: chan)
        lock.lock()
        defer {
            lock.unlock()
        }
        
        outgoingMessages[messageId] = chan
    }
    
    ws.onClose = { ws, _, _, _ in
        print("\n[CLOSED]\n")
    }
}
