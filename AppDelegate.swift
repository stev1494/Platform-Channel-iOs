

import Flutter
import FirebaseMessaging
import uSDK
import uSDK.Swift
import Foundation
import UIKit


@main
@objc class AppDelegate: FlutterAppDelegate {
    
    let viewC = UIViewController();
    
    let newViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "viewController2")
    var threeDS2Service: ThreeDS2Service = ShellThreeDS2Service();
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UIApplication.shared.isStatusBarHidden=false
        GeneratedPluginRegistrant.register(with: self)
        
        
        //Integracion 3ds
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: "app.bivi/integration_3ds/channel", binaryMessenger: controller.binaryMessenger)
        
        methodChannel.setMethodCallHandler({(call: FlutterMethodCall, result: FlutterResult)-> Void in
            
            if call.method == "initialize" {
                self.initialize()
            }
            else if call.method == "authenticate" {
                
                
                if let data = call.arguments as? Dictionary<String, String>,
                   let userId:  String  =  data["userId"],
                   let cardId:  String  =  data["cardId"],
                   let orderId: String  =  data["orderId"],
                   let splitSdkServerUrl: String =  data["splitSdkServerUrl"] ,
                   let exchangeTransactionDetailsUrl: String =  data["exchangeTransactionDetailsUrl"],
                   let transactionResultUrl:          String =  data["transactionResultUrl"] {
                    
                    self.authenticate(userId: userId, cardId: cardId, orderId: orderId, splitSdkServerUrl: splitSdkServerUrl, exchangeTransactionDetailsUrl: exchangeTransactionDetailsUrl, transactionResultUrl: transactionResultUrl, controller: controller)
                }
                
                
                result("iOS")
            }else{
                result(FlutterMethodNotImplemented)
            }
        })
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    @available(iOS 10.0,*)
    override func userNotificationCenter(_ center:UNUserNotificationCenter, willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping(UNNotificationPresentationOptions)-> Void){
        completionHandler([.alert,.sound,.badge])
    }
    override func application(_ application: UIApplication,didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data){
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken:deviceToken)
    }
    
    private func initialize()  {
        
        var initializeSpec : InitializeSpec = InitializeSpec();
        initializeSpec.locale = Locale(identifier: Locale.current.identifier)
        initializeSpec.configParameters = ConfigParameters()
        
        do {
            try threeDS2Service.initialize(spec: initializeSpec){_ in
                //result in
                print("uSDK has been successfully initialized!")
            }
        }
        catch {
            print("An exception caught during `initialize` call: \(error)")
        }
        
    }
    
    
    //@IBAction
    func authenticate(userId : String, cardId: String, orderId: String, splitSdkServerUrl : String, exchangeTransactionDetailsUrl: String,  transactionResultUrl : String, controller: FlutterViewController) {
        
        do {
            
            let authSpec = AuthenticateSpec(
                viewController: newViewController,
                cardId:  cardId,
                orderId: orderId,
                exchangeTransactionDetailsUrl: exchangeTransactionDetailsUrl,
                transactionResultUrl: transactionResultUrl,
                splitSdkServerUrl:    splitSdkServerUrl,
                userId: userId
            )
            
            try threeDS2Service.authenticate(spec: authSpec) { result in
                let channel3DSRespuesta = FlutterMethodChannel(name: "app.bivi/integration_3ds/channelRespuesta", binaryMessenger: controller.binaryMessenger)
                var arrayList : Array<String> = Array()
                
                switch result {
                case .success(let authResult):
                    
                    switch authResult {
                    case .authenticated(let authenticationResult):
                        let paymentStatus        = authenticationResult.status
                        let paymentStatusDetails = authenticationResult.threeDSServerTransID
                        let paymentID = orderId
                        
                        arrayList.append(String( describing:  paymentID))
                        arrayList.append(String( describing:  paymentStatus))
                        arrayList.append(String( describing: paymentStatusDetails))
                        
                        channel3DSRespuesta.invokeMethod("PagoOK", arguments: arrayList)
                        
                        
                    case .notAuthenticated(let authenticationResult):
                        
                        let paymentErrorDetails = authenticationResult.threeDSServerTransID
                        
                        arrayList.append(String( describing: authenticationResult.status))
                        arrayList.append(String( describing: paymentErrorDetails))
                        
                        channel3DSRespuesta.invokeMethod("PagoError", arguments: arrayList)
                        
                        
                    case .cancelled(let authenticationResult):
                        print("cancelled: \(authenticationResult)")
                    case .decoupledAuthBeingPerformed(let authenticationResult):
                        print("decoupledAuthBeingPerformed: \(authenticationResult)")
                    case .error(let authenticationResult):
                        let paymentErrorDetails = authenticationResult.error?.errorDetails
                        
                        arrayList.append(String( describing: authenticationResult))
                        arrayList.append(String( describing: paymentErrorDetails))
                        
                        channel3DSRespuesta.invokeMethod("PagoError", arguments: arrayList)
                        
                        if(authenticationResult.error?.errorCode != nil){
                            
                            let paymentErrorDetails = authenticationResult.error?.errorDetails
                            
                            arrayList.append(String( describing: authenticationResult))
                            arrayList.append(String( describing: paymentErrorDetails))
                            
                            channel3DSRespuesta.invokeMethod("PagoError", arguments: arrayList)
                        }
                        
                    }
                case.failure(let error):
                    arrayList.append(String( describing: error.self))
                    channel3DSRespuesta.invokeMethod("PagoExcepcion", arguments: arrayList)
                }
            }
        }
        catch {
            print("An exception caught during `authenticate` call: \(error)")
        }
    }
    
}
