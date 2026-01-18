import AppKit

public struct SoundManager {
    public static func playSuccess() {
        NSSound(named: "Glass")?.play()
    }
    
    public static func playError() {
        NSSound(named: "Sosumi")?.play()
    }
    
    public static func playAction() {
        NSSound(named: "Tink")?.play()
    }
}
