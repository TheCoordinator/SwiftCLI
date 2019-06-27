//
//  Parameter.swift
//  SwiftCLI
//
//  Created by Jake Heiser on 3/7/15.
//  Copyright (c) 2015 jakeheis. All rights reserved.
//

public protocol AnyParameter: AnyValueBox {
    var required: Bool { get }
    var satisfied: Bool { get }
}

public class _Param<Value: ConvertibleFromString> {
    
    public let completion: ShellCompletion
    public let validation: [Validation<Value>]
    
    /// Creates a new parameter
    ///
    /// - Parameter completion: the completion type for use in ZshCompletionGenerator; default .filename
    public init(completion: ShellCompletion = .filename, validation: [Validation<Value>] = []) {
        self.completion = completion
        self.validation = validation
    }
    
}

@propertyDelegate
public class Pram<Value: ConvertibleFromString> : _Param<Value>, AnyParameter, ValueBox {
    
    private var privValue: Value?
    public var value: Value {
        return privValue!
    }
    
    public var required: Bool { return true }
    public var satisfied = false
    
    public init() {
        super.init()
    }
    
    public override init(completion: ShellCompletion = .filename, validation: [Validation<Value>] = []) {
        super.init(completion: completion, validation: validation)
    }
    
    public func update(to value: Value) {
        self.privValue = value
    }
    
}

public protocol OptionType {
    static var empty: Self { get }
}
extension Optional: OptionType {
    public static var empty: Self { return Optional.none }
}

@propertyDelegate
public class OptPram<Value: OptionType & ConvertibleFromString> : Pram<Value> {
    
    public override var value: Value {
        return super.value
    }
    
    public override var required: Bool { return false }
    
    public override init() {
        super.init()
    }
    
    public init(initialValue: Value) {
        <#code#>
    }
    
}

//
//@propertyDelegate
//public class OptPram<Value: OptionType> : _Param<Value>, AnyParameter, ValueBox {
//
//    public var value: Value
//
//    public let required = false
//    public var satisfied = false
//
//    public init() {
//        value = Value.empty
//    }
//
//    public override init(completion: ShellCompletion = .filename, validation: [Validation<Value>] = []) {
//        value = Value.empty
//        super.init(completion: completion, validation: validation)
//    }
//
//    public func update(to value: Value) {
//        self.value = value
//    }
//
//}

public class Cmd: Command {
    public let name = "cmd"
    
    @Pram var person: String
    @OptPram var age: Int?
    
    public func execute() throws {
        print("Hello \(person)!")
        if let age = age {
            print("You are \(age) years old.")
        }
    }
}

public enum Param {
    
    public class Required<Value: ConvertibleFromString>: _Param<Value>, AnyParameter, ValueBox {
        public let required = true
        public var satisfied: Bool { return privateValue != nil }
        
        private var privateValue: Value? = nil
        
        public var value: Value {
            return privateValue!
        }
        
        public func update(to value: Value) {
            privateValue = value
        }
    }
    
    public class Optional<Value: ConvertibleFromString>: _Param<Value>, AnyParameter, ValueBox {
        public let required = false
        public let satisfied = true
        
        public var value: Value? = nil
        
        public func update(to value: Value) {
            self.value = value
        }
    }
    
}

public protocol AnyCollectedParameter: AnyParameter {}

public enum CollectedParam {
    
    public class Required<Value: ConvertibleFromString>: _Param<Value>, AnyCollectedParameter, ValueBox {
        public let required = true
        public var satisfied: Bool { return !value.isEmpty }
        
        public var value: [Value] = []
        
        public func update(to value: Value) {
            self.value.append(value)
        }
    }
    
    public class Optional<Value: ConvertibleFromString>: _Param<Value>, AnyCollectedParameter, ValueBox {
        public let required = false
        public let satisfied = true
        
        public var value: [Value] = []
        
        public func update(to value: Value) {
            self.value.append(value)
        }
    }
    
}

public typealias Parameter = Param.Required<String>
public typealias OptionalParameter = Param.Optional<String>
public typealias CollectedParameter = CollectedParam.Required<String>
public typealias OptionalCollectedParameter = CollectedParam.Optional<String>

// MARK: - NamedParameter

public struct NamedParameter {
    public let name: String
    public let param: AnyParameter
    
    public var signature: String {
        var sig = "<\(name)>"
        if param.required == false {
            sig = "[\(sig)]"
        }
        if param is AnyCollectedParameter {
            sig += " ..."
        }
        return sig
    }
    
    public init(name: String, param: AnyParameter) {
        self.name = name
        self.param = param
    }
}

// MARK: - ParameterIterator

public class ParameterIterator {
    
    private var params: [NamedParameter]
    private let collected: NamedParameter?
    
    public let minCount: Int
    public let maxCount: Int?
    
    public init(command: CommandPath) {
        var all = command.command.parameters
        
        self.minCount = all.filter({ $0.param.required }).count
        
        if let collected = all.last, collected.param is AnyCollectedParameter {
            self.collected = collected
            all.removeLast()
            self.maxCount = nil
        } else {
            self.collected = nil
            self.maxCount = all.count
        }
        
        self.params = all
        
        assert(all.firstIndex(where: { $0.param is AnyCollectedParameter }) == nil, "can only have one collected parameter, and it must be the last parameter")
        assert(all.firstIndex(where: { $0.param is OptionalParameter }).flatMap({ $0 >= minCount }) ?? true, "optional parameters must come after all required parameters")
    }
    
    public func nextIsCollection() -> Bool {
        return params.isEmpty && collected != nil
    }

    public func next() -> NamedParameter? {
        if let individual = params.first {
            params.removeFirst()
            return individual
        }
        return collected
    }
    
}

