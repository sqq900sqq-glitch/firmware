// Istighfar for iOS — native shell around the app's original HTML/JS (www/).
// Re-implements the Android bridge (MainActivity$Bridge, Reminders, Updater)
// with UIKit / WebKit / CoreLocation / UserNotifications / AVFoundation.
import UIKit
import WebKit
import CoreLocation
import UserNotifications
import AVFoundation

// MARK: - Daily istighfar reminders (strings recovered from the Android app)

enum Reminders {
    static let title = "تذكير الاستغفار"
    static let bodies = [
        "حان وقت الاستغفار، فكلُّ استغفارةٍ تُسقِط عنك ذنبًا",
        "أستغفر الله العظيم وأتوب إليه… خفِّف حِملك بدقيقة استغفار",
        "مئةُ استغفارٍ تفرغ بها وعاء الذنوب… ابدأ الآن",
        "لا تدع يومك يمضي بلا استغفار، فالوعاء ينتظرك",
        "خذ نَفَسًا وقل: أستغفر الله، ثم أكمل يومك خفيفًا",
        "وَاسْتَغْفِرُوا اللَّهَ إِنَّ اللَّهَ غَفُورٌ رَحِيمٌ",
        "رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ، إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ",
    ]
    static let hours = [9, 13, 17, 21]
    static let prefKey = "notif"

    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: prefKey) }
        set { UserDefaults.standard.set(newValue, forKey: prefKey) }
    }

    static func schedule() {
        let c = UNUserNotificationCenter.current()
        cancel()
        var i = 0
        for weekday in 1...7 {
            for h in hours {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = bodies[i % bodies.count]
                content.sound = .default
                var dc = DateComponents(); dc.weekday = weekday; dc.hour = h; dc.minute = 0
                let trig = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                c.add(UNNotificationRequest(identifier: "istg-\(weekday)-\(h)", content: content, trigger: trig))
                i += 1
            }
        }
    }

    static func cancel() {
        var ids: [String] = []
        for w in 1...7 { for h in hours { ids.append("istg-\(w)-\(h)") } }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - Web view controller

final class WebVC: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate,
                   CLLocationManagerDelegate, UIGestureRecognizerDelegate {
    var web: WKWebView!
    let loc = CLLocationManager()
    var wantLocation = false
    var wantHeading = false
    var darkBars = false
    var camSession: AVCaptureSession?
    var camLayer: AVCaptureVideoPreviewLayer?
    let www = Bundle.main.resourceURL!.appendingPathComponent("www")

    var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { darkBars ? .lightContent : .darkContent }

    func stateJS() -> String {
        let dark = traitCollection.userInterfaceStyle == .dark
        return "window.__iosState={dark:\(dark),notif:\(Reminders.enabled),version:'\(version)'};"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0xf7/255, green: 0xf1/255, blue: 0xe3/255, alpha: 1)

        let ucc = WKUserContentController()
        ucc.add(WeakHandler(self), name: "bridge")
        let bridgeURL = Bundle.main.url(forResource: "ios-bridge", withExtension: "js")!
        let bridge = (try? String(contentsOf: bridgeURL, encoding: .utf8)) ?? ""
        ucc.addUserScript(WKUserScript(source: stateJS() + bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = ucc
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        web = WKWebView(frame: view.bounds, configuration: cfg)
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate = self
        web.uiDelegate = self
        view.addSubview(web)

        // Android hardware "back" → swipe from either screen edge calls window.__back()
        for edge in [UIRectEdge.left, .right] {
            let g = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeSwipe(_:)))
            g.edges = edge
            g.delegate = self
            web.addGestureRecognizer(g)
        }

        loc.delegate = self
        web.loadFileURL(www.appendingPathComponent("istighfar.html"), allowingReadAccessTo: www)

        NotificationCenter.default.addObserver(self, selector: #selector(resync),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

    @objc func edgeSwipe(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .recognized || g.state == .ended else { return }
        js("window.__back&&window.__back()")
    }

    @objc func resync() {
        js(stateJS())
        // Reflect a change made in iOS Settings (notifications turned off there).
        UNUserNotificationCenter.current().getNotificationSettings { s in
            if s.authorizationStatus == .denied && Reminders.enabled {
                Reminders.enabled = false
                DispatchQueue.main.async { self.js(self.stateJS() + "window.__notifResult&&window.__notifResult(false)") }
            }
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        js(stateJS() + "try{if(typeof applyTheme==='function'&&THEME==='auto'){applyTheme();window.onThemeChange&&window.onThemeChange()}}catch(e){}")
    }

    func js(_ s: String) { web?.evaluateJavaScript(s, completionHandler: nil) }

    func jsonString(_ o: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) else { return "null" }
        return s
    }

    // MARK: bridge dispatch
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let m = body["m"] as? String else { return }
        let a = body["a"]
        switch m {
        case "setBarColor":
            darkBars = (a as? Bool) ?? false
            view.backgroundColor = darkBars ? UIColor(red: 0x10/255, green: 0x17/255, blue: 0x26/255, alpha: 1)
                                            : UIColor(red: 0xf7/255, green: 0xf1/255, blue: 0xe3/255, alpha: 1)
            setNeedsStatusBarAppearanceUpdate()
        case "setNotifications":
            setNotifications((a as? Bool) ?? false)
        case "requestLocation":
            requestLocation()
        case "share":
            let vc = UIActivityViewController(activityItems: [(a as? String) ?? ""], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = view
            vc.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 40, width: 1, height: 1)
            present(vc, animated: true)
        case "setPrayerAlarms":
            break // disabled in the web code itself ("prayer alerts were removed")
        case "checkUpdate":
            // Android side-loads APK updates from GitHub; on iOS updates come from the installer.
            js("window.__updateInfo&&window.__updateInfo(\(jsonString(["current": version, "available": false])))")
        case "installUpdate":
            js("window.__updateFail&&window.__updateFail('install')")
        case "vibrate":
            let ms = (a as? NSNumber)?.intValue ?? 20
            let g = UIImpactFeedbackGenerator(style: ms >= 40 ? .heavy : (ms >= 20 ? .medium : .light))
            g.impactOccurred()
        case "heading":
            wantHeading = (a as? Bool) ?? false
            if wantHeading && CLLocationManager.headingAvailable() {
                loc.headingFilter = 1
                loc.startUpdatingHeading()
            } else { loc.stopUpdatingHeading() }
        case "camera":
            if (a as? Bool) == true { startCamera() } else { stopCamera() }
        default: break
        }
    }

    // MARK: notifications
    func setNotifications(_ on: Bool) {
        if !on {
            Reminders.enabled = false; Reminders.cancel()
            js(stateJS() + "window.__notifResult&&window.__notifResult(false)")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            DispatchQueue.main.async {
                Reminders.enabled = ok
                if ok {
                    Reminders.schedule()
                    self.js(self.stateJS() + "window.__notifResult&&window.__notifResult(true);typeof toast==='function'&&toast('تم تفعيل التذكير اليومي بالاستغفار')")
                } else {
                    self.js(self.stateJS() + "window.__notifResult&&window.__notifResult(false);typeof toast==='function'&&toast('الإشعارات مغلقة لهذا التطبيق من إعدادات الهاتف')")
                }
            }
        }
    }

    // MARK: location (+ reverse geocoding like Android's Geocoder)
    func requestLocation() {
        wantLocation = true
        switch loc.authorizationStatus {
        case .notDetermined: loc.requestWhenInUseAuthorization()
        case .denied, .restricted:
            wantLocation = false
            js("window.__locResult&&window.__locResult(null,'denied')")
        default:
            loc.desiredAccuracy = kCLLocationAccuracyHundredMeters
            loc.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        guard wantLocation else { return }
        switch m.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            m.desiredAccuracy = kCLLocationAccuracyHundredMeters
            m.requestLocation()
        case .denied, .restricted:
            wantLocation = false
            js("window.__locResult&&window.__locResult(null,'denied')")
        default: break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard wantLocation, let l = locs.last else { return }
        wantLocation = false
        var o: [String: Any] = ["lat": l.coordinate.latitude, "lng": l.coordinate.longitude,
                                "gov": "", "dist": "", "city": "", "country": ""]
        let send = { self.js("window.__locResult&&window.__locResult(\(self.jsonString(o)),null)") }
        CLGeocoder().reverseGeocodeLocation(l, preferredLocale: Locale(identifier: "ar")) { pm, _ in
            if let p = pm?.first {
                o["gov"] = p.administrativeArea ?? ""
                o["dist"] = p.subAdministrativeArea ?? p.subLocality ?? ""
                o["city"] = p.locality ?? ""
                o["country"] = p.country ?? ""
            }
            DispatchQueue.main.async(execute: send)
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        guard wantLocation else { return }
        wantLocation = false
        js("window.__locResult&&window.__locResult(null,'err')")
    }

    func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        guard wantHeading else { return }
        let v = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        js("window.__iosHeading&&window.__iosHeading(\(v))")
    }

    func locationManagerShouldDisplayHeadingCalibration(_ m: CLLocationManager) -> Bool { true }

    // MARK: camera behind the transparent web view (Qibla AR mode)
    func startCamera() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async {
                guard ok, let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: dev) else {
                    self.js("window.__iosCam&&window.__iosCam(false)"); return
                }
                let s = AVCaptureSession()
                if s.canAddInput(input) { s.addInput(input) }
                let layer = AVCaptureVideoPreviewLayer(session: s)
                layer.videoGravity = .resizeAspectFill
                layer.frame = self.view.bounds
                self.view.layer.insertSublayer(layer, below: self.web.layer)
                self.camSession = s; self.camLayer = layer
                DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
                self.js("window.__iosCam&&window.__iosCam(true)")
            }
        }
    }

    func stopCamera() {
        if let s = camSession { DispatchQueue.global().async { s.stopRunning() } }
        camLayer?.removeFromSuperlayer()
        camSession = nil; camLayer = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        camLayer?.frame = view.bounds
    }

    // MARK: navigation — keep local pages inside, open anything external in Safari
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = a.request.url, let sch = u.scheme, sch != "file" && sch != "about" {
            UIApplication.shared.open(u); decisionHandler(.cancel); return
        }
        if a.request.url?.lastPathComponent != "qibla.html" && camSession != nil { stopCamera() }
        decisionHandler(.allow)
    }

    func webViewWebContentProcessDidTerminate(_ w: WKWebView) { w.reload() }

    // JS alert/confirm support
    func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage msg: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "حسنًا", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }
    func webView(_ w: WKWebView, runJavaScriptConfirmPanelWithMessage msg: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "إلغاء", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "حسنًا", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }
}

/// Avoids the WKUserContentController → handler retain cycle.
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(u, didReceive: m)
    }
}

// MARK: - App delegate

final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if Reminders.enabled { Reminders.schedule() } // like BootReceiver: re-arm reminders
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = WebVC()
        window?.makeKeyAndVisible()
        return true
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .sound])
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
