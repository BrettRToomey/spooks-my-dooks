import App
import Vapor
import Foundation

enum Error: Swift.Error {
    case missingToken
    case invalidAuthentication(String)
}

let config = try Config()
try config.setup()

let me = "@U5WHRCGA3"
let meTagged = "<\(me)>"

let blessedOnes = [
    "U0N6AKFK3",
    "U1RGR49UP",
    "U38476FJP",
    "U1S1W8TKQ"
]

let notGonnaDoIt = [
    "https://i.stack.imgur.com/m96Lc.jpg",
    "https://media.giphy.com/media/l0IydtpdUfrrvyGiY/giphy.gif",
    "https://media3.giphy.com/media/R7yQtEGaWhW36/giphy.gif",
    "https://media1.giphy.com/media/11YdnfyG6qvuWk/giphy.gif"
]

let chance = 25

guard let token = config["app", "slack"]?.string else {
    throw Error.missingToken
}

let credentials = SlackCredentials(token: token)
let rtmResponse = try startSession(credentials)

guard let url = rtmResponse.data["url"]?.string else {
    throw Error.invalidAuthentication(rtmResponse.description)
}

let lock = NSLock()

var lastYouCalled = 0.0
var outgoingMessages: [UInt32: (TimeInterval, String)] = [:]

func spook(ws: WebSocket, channel: String) throws {
    let messageId = try sendMessage(ws, message: "Boooo!", channel: channel)
    
    lock.lock()
    defer {
        lock.unlock()
    }
    
    outgoingMessages[messageId] = (1.75, channel)
}

try EngineClient.factory.socket.connect(to: url) { ws in
    ws.onText = { ws, text in
        let event = try JSON(bytes: text.utf8.array)

        if
            event["type"]?.string == "reaction_added",
            let reaction = event["reaction"]?.string,
            let item = event["item"],
            let timestamp = item["ts"]?.string,
            let chan = item["channel"]?.string
        {
            switch reaction {
            case "ghost":
                try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .ghost)
                
            case "+1", "thumbsup", "clap", "rocket", "tada":
                try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .yay)
                
            case "-1", "thumbsdown":
                try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .rage)
                
            default: break
            }
            
            return
        }
        
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
                let (timeout, chan) = outgoingMessages[replyId]
            {
                try deleteMessage(ws, credentials: credentials, channel: chan, timestamp: timestamp, timeout: timeout)
            }
            
            return
        }
        
        guard
            let chan = event["channel"]?.string,
            var message = event["text"]?.string,
            let fromId = event["user"]?.string,
            let timestamp = event["ts"]?.string
        else {
            return
        }
        
        let roll = Int.random(min: 1, max: chance)
        
        switch message {
        case "":
            break
            
        case _ where message.contains(":ghost:"):
            lock.lock()
            defer {
                lock.unlock()
            }
            
            let now = Date().timeIntervalSince1970
            
            guard now - lastYouCalled >= 60 else { return }
            
            try sendMessage(ws, message: "You called?", channel: chan)
            
            lastYouCalled = now
            
        case _ where message.contains(":flashlight:"):
            try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .disappointed)
            try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .x)
            try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .see_no_evil)
            try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .sunglasses)
            
        case _ where message.contains(":sleuth_or_spy"):
            try sendMessage(ws, message: "http://i0.kym-cdn.com/photos/images/newsfeed/000/063/491/my_trap_card.jpg", channel: chan)
            
        case _ where message.contains("cat"):
            try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .cat2)
            
        case _ where message.contains(":+1:") || message.contains(":thumbsup:"):
            try addReaction(ws: ws, credentials: credentials, channel: chan, timestamp: timestamp, reaction: .yay)
            
        case _ where message.contains("tak"):
            try sendMessage(ws, message: "mange tak", channel: chan)
            
        case _ where roll == chance:
            try spook(ws: ws, channel: chan)
            
        case _ where message.hasPrefix(meTagged):
            guard blessedOnes.contains(fromId) else {
                try sendMessage(ws, message: notGonnaDoIt[Int.random(min: 0, max: notGonnaDoIt.count - 1)], channel: chan)
                return
            }
            
            let tokens = message.components(separatedBy: " ")
            guard tokens.count > 1 else {
                try spook(ws: ws, channel: chan)
                return
            }
            
            switch tokens[1] {
            case "asl":
                try sendMessage(ws, message: fromId, channel: chan)
                
            case "dox":
                let users = tokens.dropFirst().filter {
                    return $0.contains("<@")
                }
                
                let message = users.joined(separator: ", ")
                    .replacingOccurrences(of: "<@", with: "")
                    .replacingOccurrences(of: ">", with: "")
                
                try sendMessage(ws, message: message, channel: chan)
                
            case "scare":
                guard tokens.count > 2, blessedOnes.contains(fromId) else { return }
                
                let chan = tokens[2]
                    .replacingOccurrences(of: "<#", with: "")
                    .components(separatedBy: "|")[0]
                
                try spook(ws: ws, channel: chan)
                
            default:
                break
            }
            
        default:
            return
        }
    }
    
    ws.onClose = { ws, _, _, _ in
        print("\n[CLOSED]\n")
    }
}
