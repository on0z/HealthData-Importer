//
//  ViewController.swift
//  HealthData Importer
//
//  Created by on0z on 2018/02/20.
//  Copyright © 2018年 on0z. All rights reserved.
//

import UIKit
import CloudKit
import HealthKit

class ViewController: UIViewController, XMLParserDelegate {

    @IBOutlet weak var startButton: UIButton!
    
    var url: URL?
    
    @IBAction func start(sender: UIButton){
        startButton.isEnabled = false
        
        let docdirpath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        xmlparse(url: URL(fileURLWithPath: docdirpath+"/export.xml"))
    }
    
    func updateStatus(){
        if healthObjects.count % 1000 == 0{
            print(healthObjects.count)
        }
        
        //---
        /*
        if self.saveCount % 1000 == 0{
            print(self.saveCount)
        }*/
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        //let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsPath + "/myfile.txt"
        if !fm.fileExists(atPath: filePath) {
            fm.createFile(atPath: filePath, contents: nil, attributes: [:])
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - XMLParser
    
    var parser: XMLParser!
    
    func xmlparse(url: URL) {
        guard let _parser: XMLParser = XMLParser(contentsOf: url) else { return }
        self.parser = _parser
        parser.delegate = self
        parser.parse()
    }
    
    // MARK: - XMLParserDelegate
    
    var inHealthDataFlag: Bool = false
    var inRecordFlag = false
    var inMetadataEntryFlag = false
    var inWorkoutFlag = false
    var inWorkoutEventFlag = false
    var inActivitySummaryFlag = false
    
    var type: String = ""
    var device: String?
    var unit: String = ""
    var startDate: String = ""
    var endDate: String = ""
    var value: String = ""
    var currentMetaData: [String : Any] = [:]
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
//        print("elementName:", elementName, "{")
//        print("attributeDict: ", attributeDict)
        switch elementName{
        case  "HealthData":
            inHealthDataFlag = true
            break
        case "Record":
            inRecordFlag = true
            break
        case "MetadataEntry":
            inMetadataEntryFlag = true
            break
        case "Workout":
            inWorkoutFlag = true
            break
        case "WorkoutEvent":
            inWorkoutEventFlag = true
            break
        case "ActivitySummary":
            inActivitySummaryFlag = true
            break
        default: break
        }
        
        if inHealthDataFlag{
            if elementName == "Record"{
                guard let _type = attributeDict["type"] else { print("☠️004001 type notfound"); return}
                device = attributeDict["device"]
                unit = attributeDict["unit"] ?? ""// else { print("☠️004004 unit notfound"); return}
                guard let _startDate = attributeDict["startDate"] else { print("☠️004006 start Date notfound"); return}
                guard let _endDate = attributeDict["endDate"] else { print("☠️004007 end Date notfound"); return}
                guard let _value = attributeDict["value"] else { print("☠️004008 value notfound"); return}
                type = _type
//                unit = _unit
                startDate = _startDate
                endDate = _endDate
                value = _value
            }else if self.inRecordFlag && elementName == "MetadataEntry"{
                guard let key = attributeDict["key"] else { print("☠️004011 MetadataEntry key notfound"); return}
                guard let value = attributeDict["value"] else { print("☠️004012 MetadataEntry value notfound"); return}
                currentMetaData[key] = value
            }else if elementName == "Workout"{
                
            }else if inWorkoutFlag && elementName == "WorkoutEvent"{
                
            }else if elementName == "ActivitySummary"{
                
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if inHealthDataFlag{
            if elementName == "Record"{
                if self.type.contains("HKQuantity"){
                    self.saveQuantity(
                        type: type,
                        device: device,
                        unit: unit,
                        startDate: startDate,
                        endDate: endDate,
                        value: value,
                        metadata: currentMetaData)
                }else if self.type.contains("HKCategory"){
                    self.saveCategory(
                        type: type,
                        device: device,
                        startDate: startDate,
                        endDate: endDate,
                        value: value,
                        metadata: currentMetaData)
                }else{
                    print("☠️004000 unknown")
                }
                type = ""
                device = nil
                unit = ""
                startDate = ""
                endDate = ""
                value = ""
                currentMetaData = [:]
            }else if elementName == "Workout"{
                
            }else if elementName == "ActivitySummary"{
                
            }
        }
        
        switch elementName{
        case  "HealthData":
            inHealthDataFlag = false
            break
        case "Record":
            inRecordFlag = false
            break
        case "MetadataEntry":
            inMetadataEntryFlag = false
            break
        case "Workout":
            inWorkoutFlag = false
            break
        case "WorkoutEvent":
            inWorkoutEventFlag = false
            break
        case "ActivitySummary":
            inActivitySummaryFlag = false
            break
        default: break
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        /// 即保存バージョン
        
        //---
        
        /// まとめて保存バージョン
        saveHealthKit()
    }
    
    // MARK: - save to Health Kit
    
    let healthStore = HKHealthStore()
    
    //各タイプ毎のデータ数。requestAuthorizationの引数toShareで使う目的も兼ねている
    var typeDic: [HKSampleType : Int] = [:]
    //集計したデータ
    var healthObjects: [HKObject] = []
    //保存したデータの数
//    var saveCount: Int = 0
    
    @available(iOS 9.0, *)
    func getDevice(_ str: String?) -> HKDevice?{
//        HKDevice(name: <#T##String?#>, manufacturer: <#T##String?#>, model: <#T##String?#>, hardwareVersion: <#T##String?#>, firmwareVersion: <#T##String?#>, softwareVersion: <#T##String?#>, localIdentifier: <#T##String?#>, udiDeviceIdentifier: <#T##String?#>)
        return nil
    }
    
    func getDate(from string: String, format: String = "yyyy-MM-dd HH:mm:SS Z") -> Date{
        let formatter: DateFormatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter.date(from: string)!
    }
    
    // もし'Invalid class NSTaggedPointerString for metadata key: HKWeatherTemperature. Expected HKQuantity.'などのエラーが出たらここをチェック
    func loadMetadataEntry(metadata: [String: Any]?) -> [String : Any]?{
        guard let metadata = metadata else { return nil }
        var result = metadata
        for (key, value) in metadata{
            if #available(iOS 11.0, *) {
                switch key{
                case HKMetadataKeyTimeZone,
                     HKMetadataKeyWasUserEntered,
                     HKMetadataKeyWeatherCondition,
                     HKMetadataKeySyncVersion,
                     HKMetadataKeyWasTakenInLab,
                     HKMetadataKeyReferenceRangeLowerLimit,
                     HKMetadataKeyReferenceRangeUpperLimit,
                     HKMetadataKeyBodyTemperatureSensorLocation,
                     HKMetadataKeyHeartRateSensorLocation,
                     HKMetadataKeyHeartRateMotionContext,
                     HKMetadataKeyVO2MaxTestType,
                     HKMetadataKeyBloodGlucoseMealTime,
                     HKMetadataKeyInsulinDeliveryReason,
                     HKMetadataKeyMenstrualCycleStart,
                     HKMetadataKeySexualActivityProtectionUsed:
                    //NSNumber系
                    guard let i = Double(value as! String) else { continue }
                    result.updateValue(NSNumber(value: i), forKey: key)
                case HKMetadataKeyWeatherTemperature,
                     HKMetadataKeyWeatherHumidity:
                    result.removeValue(forKey: key)
                case HKMetadataKeyDeviceSerialNumber,
                     HKMetadataKeyUDIDeviceIdentifier,
                     HKMetadataKeyUDIProductionIdentifier,
                     HKMetadataKeyDigitalSignature,
                     HKMetadataKeyDeviceName,
                     HKMetadataKeyDeviceManufacturerName:
                    // Device系
                    result.removeValue(forKey: key)
                default: break
                }
            }else if #available(iOS 10.0, *) {
                switch key{
                case HKMetadataKeyTimeZone,
                     HKMetadataKeyWasUserEntered,
                     HKMetadataKeyWeatherCondition,
                     HKMetadataKeyWasTakenInLab,
                     HKMetadataKeyReferenceRangeLowerLimit,
                     HKMetadataKeyReferenceRangeUpperLimit,
                     HKMetadataKeyBodyTemperatureSensorLocation,
                     HKMetadataKeyHeartRateSensorLocation,
                     HKMetadataKeyMenstrualCycleStart,
                     HKMetadataKeySexualActivityProtectionUsed:
                    //NSNumber系
                    guard let i = Double(value as! String) else { continue }
                    result.updateValue(NSNumber(value: i), forKey: key)
                case HKMetadataKeyWeatherTemperature,
                     HKMetadataKeyWeatherHumidity:
                    result.removeValue(forKey: key)
                case HKMetadataKeyDeviceSerialNumber,
                     HKMetadataKeyUDIDeviceIdentifier,
                     HKMetadataKeyUDIProductionIdentifier,
                     HKMetadataKeyDigitalSignature,
                     HKMetadataKeyDeviceName,
                     HKMetadataKeyDeviceManufacturerName:
                    // Device系
                    result.removeValue(forKey: key)
                default: break
                }
            }else if #available(iOS 9.0, *) {
                switch key{
                case HKMetadataKeyTimeZone,
                     HKMetadataKeyWasUserEntered,
                     HKMetadataKeyWasTakenInLab,
                     HKMetadataKeyReferenceRangeLowerLimit,
                     HKMetadataKeyReferenceRangeUpperLimit,
                     HKMetadataKeyBodyTemperatureSensorLocation,
                     HKMetadataKeyHeartRateSensorLocation,
                     HKMetadataKeyMenstrualCycleStart,
                     HKMetadataKeySexualActivityProtectionUsed:
                    //NSNumber系
                    guard let i = Double(value as! String) else { continue }
                    result.updateValue(NSNumber(value: i), forKey: key)
                case HKMetadataKeyDeviceSerialNumber,
                     HKMetadataKeyUDIDeviceIdentifier,
                     HKMetadataKeyUDIProductionIdentifier,
                     HKMetadataKeyDigitalSignature,
                     HKMetadataKeyDeviceName,
                     HKMetadataKeyDeviceManufacturerName:
                    // Device系
                    result.removeValue(forKey: key)
                default: break
                }
            } else {
                switch key{
                case HKMetadataKeyTimeZone,
                     HKMetadataKeyWasUserEntered,
                     HKMetadataKeyWasTakenInLab,
                     HKMetadataKeyReferenceRangeLowerLimit,
                     HKMetadataKeyReferenceRangeUpperLimit,
                     HKMetadataKeyBodyTemperatureSensorLocation,
                     HKMetadataKeyHeartRateSensorLocation:
                    //NSNumber系
                    guard let i = Double(value as! String) else { continue }
                    result.updateValue(NSNumber(value: i), forKey: key)
                case HKMetadataKeyDeviceSerialNumber,
                     HKMetadataKeyUDIDeviceIdentifier,
                     HKMetadataKeyUDIProductionIdentifier,
                     HKMetadataKeyDigitalSignature,
                     HKMetadataKeyDeviceName,
                     HKMetadataKeyDeviceManufacturerName:
                    // Device系
                    result.removeValue(forKey: key)
                default: break
                }
            }
        }
        return result
    }
    
    //MARK: Qutantity
    func saveQuantity(type: String, device: String?, unit: String, startDate: String, endDate: String, value: String, metadata: [String : Any]?){
        // 'Authorization to share the following types is disallowed: HKQuantityTypeIdentifierWalkingHeartRateAverage' 等
        guard type != "HKQuantityTypeIdentifierAppleExerciseTime" else { return }
        guard type != "HKQuantityTypeIdentifierWalkingHeartRateAverage" else { return }
        
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: type)) else { print("☠️005101 nil type"); return }
        guard let doubleValue: Double = Double(value) else { print("☠️005102 nil double value"); return }
        
        /// まとめて保存用処理
        if let _ = typeDic[quantityType as HKSampleType]{
            typeDic[quantityType as HKSampleType]! += 1
        }else{
            typeDic[quantityType as HKSampleType] = 1
        }
        
        let quantityValue = HKQuantity(unit: HKUnit(from: unit), doubleValue: doubleValue)
        if #available(iOS 9.0, *) {
            
            /// まとめて保存バージョン
            self.healthObjects.append(
                HKQuantitySample(
                    type: quantityType,
                    quantity: quantityValue,
                    start: self.getDate(from: startDate),
                    end: self.getDate(from: endDate),
                    device: self.getDevice(device),
                    metadata: loadMetadataEntry(metadata: metadata)
                )
            )
            
            //---
            
            /// 即保存バージョン
            /*DispatchQueue.global().async {
                self.healthStore.requestAuthorization(toShare: [quantityType], read: nil) { (success, error) in
                    if success{
                        self.healthStore.save(
                            HKQuantitySample(
                                type: quantityType,
                                quantity: quantityValue,
                                start: self.getDate(from: startDate),
                                end: self.getDate(from: endDate),
                                device: self.getDevice(device),
                                metadata: self.loadMetadataEntry(metadata: metadata)
                            ),
                            withCompletion: { (success, error) in
                                if success{
                                    print("save succeeded!")
                                }else if let error = error{
                                    print("☠️005001 save failed\n[error]:", error)
                                }else{
                                    print("☠️005002 save failed. nil error")
                                }
                        })
                    }
                }
            }*/
        } else {
    
            /// まとめて保存バージョン
            self.healthObjects.append(
                HKQuantitySample(
                    type: quantityType,
                    quantity: quantityValue,
                    start: self.getDate(from: startDate),
                    end: self.getDate(from: endDate),
                    metadata: loadMetadataEntry(metadata: metadata)
                )
            )
            
            //---
    
            /// 即保存バージョン
            /*DispatchQueue.global().async {
                self.healthStore.requestAuthorization(toShare: [quantityType], read: nil) { (success, error) in
                    if success{
                        self.healthStore.save(
                            HKQuantitySample(
                                type: quantityType,
                                quantity: quantityValue,
                                start: self.getDate(from: startDate),
                                end: self.getDate(from: endDate),
                                metadata: self.loadMetadataEntry(metadata: metadata)
                            ),
                            withCompletion: { (success, error) in
                                if success{
                                    print("save succeeded!")
                                }else if let error = error{
                                    print("☠️005001 save failed\n[error]:", error)
                                }else{
                                    print("☠️005002 save failed. nil error")
                                }
                        })
                    }
                }
            }*/
            
        }
//        self.saveCount += 1
        updateStatus()
    }
    
    //MARK: Category
    func getCategoryValue(value: String) -> Int{
        switch value{
        case "HKCategoryValueSleepAnalysisInBed":
            return HKCategoryValueSleepAnalysis.inBed.rawValue
        case "HKCategoryValueSleepAnalysisAsleep":
            return HKCategoryValueSleepAnalysis.asleep.rawValue
        case "HKCategoryValueSleepAnalysisAwake":
            if #available(iOS 10.0, *) {
                return HKCategoryValueSleepAnalysis.awake.rawValue
            }
            break
        default:
            break
        }
        if #available(iOS 10.0, *){
            switch value{
            case "HKCategoryValueSleepAnalysisAwake":
                return HKCategoryValueSleepAnalysis.awake.rawValue
            default:
                break
            }
        }
        
        if #available(iOS 9.0, *){
            switch value{
            case "HKCategoryValueAppleStandHourIdle":
                return HKCategoryValueAppleStandHour.idle.rawValue
            case "HKCategoryValueAppleStandHourStood":
                return HKCategoryValueAppleStandHour.stood.rawValue
            case "HKCategoryValueMenstrualFlowHeavy":
                return HKCategoryValueMenstrualFlow.heavy.rawValue
            case "HKCategoryValueMenstrualFlowLight":
                return HKCategoryValueMenstrualFlow.light.rawValue
            case "HKCategoryValueMenstrualFlowMedium":
                return HKCategoryValueMenstrualFlow.medium.rawValue
            case "HKCategoryValueOvulationTestResultIndeterminate":
                return HKCategoryValueOvulationTestResult.indeterminate.rawValue
            case "HKCategoryValueOvulationTestResultNegatice":
                return HKCategoryValueOvulationTestResult.negative.rawValue
            case "HKCategoryValueOvulationTestResultPositive":
                return HKCategoryValueOvulationTestResult.positive.rawValue
            case "HKCategoryValueCervicalMucusQualityCreamy":
                return HKCategoryValueCervicalMucusQuality.creamy.rawValue
            case "HKCategoryValueCervicalMucusQualityDry":
                return HKCategoryValueCervicalMucusQuality.dry.rawValue
            case "HKCategoryValueCervicalMucusQualityEggWhite":
                return HKCategoryValueCervicalMucusQuality.eggWhite.rawValue
            case "HKCategoryValueCervicalMucusQualitySticky":
                return HKCategoryValueCervicalMucusQuality.sticky.rawValue
            case "HKCategoryValueCervicalMucusQualityWatery":
                return HKCategoryValueCervicalMucusQuality.watery.rawValue
            default:
                break
            }
        }
        print("⚠️005202 unknown value")
        return 0
    }
    
    func saveCategory(type: String, device: String?, startDate: String, endDate: String, value: String, metadata: [String : Any]?){
        guard type != "HKCategoryTypeIdentifierAppleStandHour" else { return }
        guard let categoryType = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue:type)) else { print("☠️005201 nil type"); return }
        
        /// まとめて保存用処理
        if let _ = typeDic[categoryType as HKSampleType]{
            typeDic[categoryType as HKSampleType]! += 1
        }else{
            typeDic[categoryType as HKSampleType] = 1
        }
        
        if #available(iOS 9.0, *) {
            
            /// まとめて保存バージョン
            self.healthObjects.append(
                HKCategorySample(
                    type: categoryType,
                    value: getCategoryValue(value: value),
                    start: self.getDate(from: startDate),
                    end: self.getDate(from: endDate),
                    device: self.getDevice(device),
                    metadata: loadMetadataEntry(metadata: metadata)
                )
            )
            
            //---
            
            /// 即保存バージョン
            /*DispatchQueue.global().async {
                self.healthStore.requestAuthorization(toShare: [categoryType], read: nil) { (success, error) in
                    if success{
                        self.healthStore.save(
                            HKCategorySample(
                                type: categoryType,
                                value: self.getCategoryValue(value: value),
                                start: self.getDate(from: startDate),
                                end: self.getDate(from: endDate),
                                device: self.getDevice(device),
                                metadata: self.loadMetadataEntry(metadata: metadata)
                            ),
                            withCompletion: { (success, error) in
                                if success{
                                    print("save succeeded!")
                                }else if let error = error{
                                    print("☠️005001 save failed\n[error]:", error)
                                }else{
                                    print("☠️005002 save failed. nil error")
                                }
                        })
                    }
                }
            }*/
        } else {
            
            /// まとめて保存バージョン
            self.healthObjects.append(
                HKCategorySample(
                    type: categoryType,
                    value: getCategoryValue(value: value),
                    start: self.getDate(from: startDate),
                    end: self.getDate(from: endDate),
                    metadata: loadMetadataEntry(metadata: metadata)
                )
            )
            
            //---
            
            /// 即保存バージョン
            /*DispatchQueue.global().async {
                self.healthStore.requestAuthorization(toShare: [categoryType], read: nil) { (success, error) in
                    if success{
                        self.healthStore.save(
                            HKCategorySample(
                                type: categoryType,
                                value: self.getCategoryValue(value: value),
                                start: self.getDate(from: startDate),
                                end: self.getDate(from: endDate),
                                metadata: self.loadMetadataEntry(metadata: metadata)
                            ),
                            withCompletion: { (success, error) in
                                if success{
                                    print("save succeeded!")
                                }else if let error = error{
                                    print("☠️005001 save failed\n[error]:", error)
                                }else{
                                    print("☠️005002 save failed. nil error")
                                }
                        })
                    }
                }
            }*/
        }
//        self.saveCount += 1
        updateStatus()
    }

    //MARK: Workout
    func getWorkoutActivityType(type: String) -> HKWorkoutActivityType{
        switch type{
        case "HKWorkoutActivityTypeAmericanFootball":
            return .americanFootball
        case "HKWorkoutActivityTypeArchery":
            return .archery
        case "HKWorkoutActivityTypeAustralianFootball":
            return .australianFootball
        case "HKWorkoutActivityTypeBadminton":
            return .badminton
        case "HKWorkoutActivityTypeBaseball":
            return .baseball
        case "HKWorkoutActivityTypeBasketball":
            return .basketball
        case "HKWorkoutActivityTypeBowling":
            return .bowling
        case "HKWorkoutActivityTypeBoxing":
            return .boxing
        case "HKWorkoutActivityTypeClimbing":
            return .climbing
        case "HKWorkoutActivityTypeCricket":
            return .cricket
        case "HKWorkoutActivityTypeCrossTraining":
            return .crossTraining
        case "HKWorkoutActivityTypeCurling":
            return .curling
        case "HKWorkoutActivityTypeCycling":
            return .cycling
        case "HKWorkoutActivityTypeDance":
            return .dance
        case "HKWorkoutActivityTypeDanceInspiredTraining":
            return .danceInspiredTraining
        case "HKWorkoutActivityTypeElliptical":
            return .elliptical
        case "HKWorkoutActivityTypeEquestrianSports":
            return .equestrianSports
        case "HKWorkoutActivityTypeFencing":
            return .fencing
        case "HKWorkoutActivityTypeFishing":
            return .fishing
        case "HKWorkoutActivityTypeFunctionalStrengthTraining":
            return .functionalStrengthTraining
        case "HKWorkoutActivityTypeGolf":
            return .golf
        case "HKWorkoutActivityTypeGymnastics":
            return .gymnastics
        case "HKWorkoutActivityTypeHandball":
            return .handball
        case "HKWorkoutActivityTypeHiking":
            return .hiking
        case "HKWorkoutActivityTypeHockey":
            return .hockey
        case "HKWorkoutActivityTypeHunting":
            return .hunting
        case "HKWorkoutActivityTypeLacrosse":
            return .lacrosse
        case "HKWorkoutActivityTypeMartialArts":
            return .martialArts
        case "HKWorkoutActivityTypeMindAndBody":
            return .mindAndBody
        case "HKWorkoutActivityTypeMixedMetabolicCardioTraining":
            return .mixedMetabolicCardioTraining
        case "HKWorkoutActivityTypePaddleSports":
            return .paddleSports
        case "HKWorkoutActivityTypePlay":
            return .play
        case "HKWorkoutActivityTypePreparationAndRecovery":
            return .preparationAndRecovery
        case "HKWorkoutActivityTypeRacquetball":
            return .racquetball
        case "HKWorkoutActivityTypeRowing":
            return .rowing
        case "HKWorkoutActivityTypeRugby":
            return .rugby
        case "HKWorkoutActivityTypeRunning":
            return .running
        case "HKWorkoutActivityTypeSailing":
            return .sailing
        case "HKWorkoutActivityTypeSkatingSports":
            return .skatingSports
        case "HKWorkoutActivityTypeSnowSports":
            return .snowSports
        case "HKWorkoutActivityTypeSoccer":
            return .soccer
        case "HKWorkoutActivityTypeSoftball":
            return .softball
        case "HKWorkoutActivityTypeSquash":
            return .squash
        case "HKWorkoutActivityTypeStairClimbing":
            return .stairClimbing
        case "HKWorkoutActivityTypeSurfingSports":
            return .surfingSports
        case "HKWorkoutActivityTypeSwimming":
            return .swimming
        case "HKWorkoutActivityTypeTableTennis":
            return .tableTennis
        case "HKWorkoutActivityTypeTennis":
            return .tennis
        case "HKWorkoutActivityTypeTrackAndField":
            return .trackAndField
        case "HKWorkoutActivityTypeTraditionalStrengthTraining":
            return .traditionalStrengthTraining
        case "HKWorkoutActivityTypeVolleyball":
            return .volleyball
        case "HKWorkoutActivityTypeWalking":
            return .walking
        case "HKWorkoutActivityTypeWaterFitness":
            return .waterFitness
        case "HKWorkoutActivityTypeWaterPolo":
            return .waterPolo
        case "HKWorkoutActivityTypeWaterSports":
            return .waterSports
        case "HKWorkoutActivityTypeWrestling":
            return .wrestling
        case "HKWorkoutActivityTypeYoga":
            return .yoga
        case "HKWorkoutActivityTypeOther":
            return .other
        default:
            break
        }
        if #available(iOS 10.0, *){
            switch type{
            case "HKWorkoutActivityTypeBarre":
                return .barre
            case "HKWorkoutActivityTypeCoreTraining":
                return .coreTraining
            case "HKWorkoutActivityTypeCrossCountrySkiing":
                return .crossCountrySkiing
            case "HKWorkoutActivityTypeDownhillSkiing":
                return .downhillSkiing
            case "HKWorkoutActivityTypeFlexibility":
                return .flexibility
            case "HKWorkoutActivityTypeHighIntensityIntervalTraining":
                return .highIntensityIntervalTraining
            case "HKWorkoutActivityTypeJumpRope":
                return .jumpRope
            case "HKWorkoutActivityTypeKickboxing":
                return .kickboxing
            case "HKWorkoutActivityTypePilates":
                return .pilates
            case "HKWorkoutActivityTypeSnowboarding":
                return .snowboarding
            case "HKWorkoutActivityTypeStairs":
                return .stairs
            case "HKWorkoutActivityTypeStepTraining":
                return .stepTraining
            case "HKWorkoutActivityTypeWheelchairWalkPace":
                return .wheelchairWalkPace
            case "HKWorkoutActivityTypeWheelchairRunPace":
                return .wheelchairRunPace
            default:
                break
            }
        }
        if #available(iOS 11.0, *){
            switch type{
            case "HKWorkoutActivityTypeTaiChi":
                return .taiChi
            case "HKWorkoutActivityTypeMixedCardio":
                return .mixedCardio
            case "HKWorkoutActivityTypeHandCycling":
                return .handCycling
            default:
                break
            }
        }
        return .other
    }
    
    func getDuration(duration: String, durationUnit: String) throws -> TimeInterval{
        guard let double = Double(duration) else { throw myError.double }
        switch durationUnit {
        case "sec":
            return TimeInterval(double)
        case "min":
            return TimeInterval(double * 60)
        case "hour":
            return TimeInterval(double * 60 * 60)
        default:
            throw myError.unknown
        }
    }
    
    enum myError: Error{
        case double
        case unknown
        case `default`
    }
    
    func getEnergyBurned(totalEnergyBurned: String?, totalEnergyBurnedUnit: String?) -> HKQuantity?{
        return nil
    }
    
    func getDistance(totalDistance: String?, totalDistanceUnit: String?) -> HKQuantity?{
        return nil
    }
    
    func saveWorkout(type: String, duration: String, durationUnit: String, totalDistance: String?, totalDistanceUnit: String?, totalEnergyBurned: String?, totalEnergyBurnedUnit: String?, device: String?, startDate: String, endDate: String){
        //まだ何もしてない
        //updateStatus()
    }
    
    //MARK: ActivitySummery
    
    //MARK: save
    
    func saveHealthKit(){
        print(typeDic)
        print(healthObjects.count)
        let writeSet = Set(typeDic.keys)
        DispatchQueue.global().async {
            self.healthStore.requestAuthorization(toShare: writeSet, read: nil){ (success, error) -> Void in
                if success {
                    /// バラバラに保存バージョン
                    /*for i in 0...self.healthObjects.count{
                        self.healthStore.save([self.healthObjects[i]], withCompletion: {(success, error) in
                            if success {
                                print("save succeeded! \(i)")
                            }else if let error = error{
                                print("☠️005001 save failed\n[error]:", error)
                            }else{
                                print("☠️005002 save failed. nil error")
                            }
                        })
                    }*/
                    
                    /// まとめて保存バージョン
                    self.healthStore.save(self.healthObjects, withCompletion: { (success, error) in
                        if success{
                            print("save succeeded!")
                        }else if let error = error{
                            print("☠️005001 save failed\n[error]:", error)
                        }else{
                            print("☠️005002 save failed. nil error")
                        }
                    })
                    self.typeDic = [:]
                    self.healthObjects = []
                }else{
                    print("☠️005000 requestAuthorization failed")
                }
            }
        }
    }
}
