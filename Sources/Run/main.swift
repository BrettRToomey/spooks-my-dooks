import App
import Vapor
import Foundation

enum FuckMe: Error {
    case missingToken
    case invalidAuthentication(String)
}

let config = try Config()
try config.setup()

let me = "@U5WHRCGA3"
let meTagged = "<\(me)>"

let specialSpookers = [
    "U1ADS4ML7",
    "U0N81DSSH",
    "U0N6AKFK3",
    "U1RGR49UP",
    "U38476FJP"
]
let spookingSpookers = [
    "http://66.media.tumblr.com/tumblr_luw339D4pe1qhv5ilo2_r1_500.gif",
    "http://orig10.deviantart.net/ebab/f/2014/224/1/9/spooked_my_guts_off_by_dinodilopho-d7uvsz5.png",
    "https://cdn.meme.am/cache/instances/folder877/500x/70732877/racist-ghost-wasp-youve-been-spooked-by-the-ghost-wasp-send-it-to-ten-friends-or-be-attacked-by-spoo.jpg",
    "https://ci.memecdn.com/9568539.gif",
    "https://cdn.meme.am/cache/instances/folder941/63288941.jpg",
    "http://s2.quickmeme.com/img/3e/3e36157885a1d2ee5de0831f0ae951deb3d94161ebd49d6a45c353a4e529e40e.jpg",
    "https://ci.memecdn.com/8871354.jpg",
    "https://pics.onsizzle.com/Facebook-ef39da.png",
    "https://i.imgflip.com/19ol7o.jpg",
    "https://pics.onsizzle.com/when-u-see-the-spooky-memes-~lara-1425581.png"
]

let chance = 100 // 1 in 100

guard let token = config["app", "slack"]?.string else {
    throw FuckMe.missingToken
}

let credentials = SlackCredentials(token: token)
let rtmResponse = try startSession(credentials)

guard let url = rtmResponse.data["url"]?.string else {
    throw FuckMe.invalidAuthentication(rtmResponse.description)
}

let lock = NSLock()
var outgoingMessages: [UInt32: (TimeInterval, String)] = [:]

func spook(ws: WebSocket, user: String, channel: String) throws {
    let message: String
    let timeout: TimeInterval
    if specialSpookers.contains(user) {
        let index = Int.random(min: 0, max: spookingSpookers.count - 1)
        message = spookingSpookers[index]
        timeout = 3.0
    } else {
        message = "Boooo!"
        timeout = 1.75
    }
    
    let messageId = try sendMessage(ws, message: message, channel: channel)
    lock.lock()
    defer {
        lock.unlock()
    }
    
    outgoingMessages[messageId] = (timeout, channel)
}

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
            let timestamp = event["ts"].flatMap({ $0.string.flatMap({ Double($0) }) })
        else {
            return
        }
        
        let roll = Int.random(min: 1, max: chance)
        
        switch message {
        case _ where roll == chance:
            try spook(ws: ws, user: fromId, channel: chan)
            
        case _ where message.hasPrefix(meTagged):
            let tokens = message.components(separatedBy: " ")
            guard tokens.count > 1 else {
                try spook(ws: ws, user: fromId, channel: chan)
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
