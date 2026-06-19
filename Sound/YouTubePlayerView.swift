import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !videoID.isEmpty else { return }

        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; }
                html, body { width: 100%; height: 100%; background: black; }
                .video-wrap {
                    position: absolute; top: 0; left: 0;
                    width: 100%; height: 100%;
                }
                iframe {
                    position: absolute; top: 0; left: 0;
                    width: 100%; height: 100%; border: 0;
                }
            </style>
        </head>
        <body>
            <div class="video-wrap">
                <iframe
                    src="https://www.youtube.com/embed/\(videoID)?playsinline=1&autoplay=1&rel=0"
                    frameborder="0"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """

        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
    }
}

// Helper to extract video ID from various YouTube URL formats
struct YouTubeURLParser {
    static func extractVideoID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If it's already just an ID (11 characters, alphanumeric with - and _)
        if trimmed.count == 11, trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            return trimmed
        }

        guard let url = URL(string: trimmed) else { return nil }
        let host = url.host?.lowercased() ?? ""

        // youtu.be/VIDEOID
        if host.contains("youtu.be") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }

        // youtube.com/watch?v=VIDEOID
        if host.contains("youtube.com") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let id = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return id
            }
            // youtube.com/embed/VIDEOID or youtube.com/shorts/VIDEOID
            let pathParts = url.pathComponents
            if let lastPart = pathParts.last, lastPart != "/", pathParts.count > 2 {
                return lastPart
            }
        }

        return nil
    }
}
