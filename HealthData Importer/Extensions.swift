//
//  Extensions.swift
//  HealthData Importer
//
//  Created by on0z on 2018/02/20.
//  Copyright © 2018年 on0z. All rights reserved.
//

import Foundation

extension String{
    public func split(pattern: String, keep: Bool) throws -> [String] {
        var location = 0
        var rtn = [String]()
        let results = try NSRegularExpression(pattern: pattern)
            .matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        for result in results{
            let range = result.range
            let notMatch = (self as NSString).substring(with: NSRange(location: location, length: range.location - location))
            if notMatch != "" { rtn.append(notMatch) }
            location = range.location
            if keep{
                let matched = (self as NSString).substring(with: NSRange(location: location, length: range.length))
                if matched != "" { rtn.append(matched) }
            }
            location += range.length
        }
        let notMatch = (self as NSString).substring(with: NSRange(location: location, length: self.count - location))
        if notMatch != "" { rtn.append(notMatch)}
        return rtn
    }
    
    public func replace(pattern: String, with: ((_ offset: Int, _ element: NSTextCheckingResult, _ string: String) throws -> String), options: NSRegularExpression.Options = []) throws -> String {
        var location = 0
        var rtn = [String]()
        let results = try NSRegularExpression(pattern: pattern)
            .matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        for result in results.enumerated(){
            let range = result.element.range
            let notMatch = (self as NSString).substring(with: NSRange(location: location, length: range.location - location))
            if notMatch != "" { rtn.append(notMatch)}
            let matched = try with(result.offset, result.element, (self as NSString).substring(with: result.element.range))
            if matched != "" { rtn.append(matched)}
            location = range.location + range.length
        }
        let notMatch = (self as NSString).substring(with: NSRange(location: location, length: self.count - location))
        if notMatch != "" { rtn.append(notMatch)}
        return rtn.joined(separator: "")
    }
    
}
