//
//  Compiler.swift
//  SwiftBFPackageDescription
//
//  Created by Andy Best on 24/08/2017.
//

import Foundation
import LLVM
import cllvm

class BFCompiler {
    
    let module = Module(name: "main")
    var putcFunc: IRValue?
    
    init(source: String) {
        // Clean the source of all non-opcode characters
        var cleanedSource = ""
        
        let opcodeSet = CharacterSet(charactersIn: "+-<>,.[]")
        for s in source.unicodeScalars {
            if opcodeSet.contains(s) {
                cleanedSource.append(Character(s))
            }
        }
        
        let reader = BFReader(source: cleanedSource)
        let ast = reader.genAst()
        
        emitIR(ast)
    }
    
    fileprivate func irLoop(_ ast: [BfAstNode], _ builder: IRBuilder, _ memory: IRValue, _ dataPointer: IRValue, _ main: Function, _ loopCount: inout Int) {
        for node in ast {
            switch node {
            case .add(let val):
                let memPtr = builder.buildInBoundsGEP(memory, indices: [IntType.int16.zero(), builder.buildLoad(dataPointer)])
                let tempVal = builder.buildAdd(builder.buildLoad(memPtr), IntType.int8.constant(val))
                builder.buildStore(tempVal, to: memPtr)
            case .subtract(let val):
                let memPtr = builder.buildInBoundsGEP(memory, indices: [IntType.int16.zero(), builder.buildLoad(dataPointer)])
                let tempVal = builder.buildSub(builder.buildLoad(memPtr), IntType.int8.constant(val))
                builder.buildStore(tempVal, to: memPtr)
            case .incDataPointer(let val):
                let tempVal = builder.buildAdd(builder.buildLoad(dataPointer), IntType.int16.constant(val))
                builder.buildStore(tempVal, to: dataPointer)
            case .decDataPointer(let val):
                let tempVal = builder.buildSub(builder.buildLoad(dataPointer), IntType.int16.constant(val))
                builder.buildStore(tempVal, to: dataPointer)
            case .loop(let nodes):
                let loopHead = main.appendBasicBlock(named: "loop\(loopCount)")
                let loopStart = main.appendBasicBlock(named: "loop\(loopCount)Start")
                let loopEnd = main.appendBasicBlock(named: "loop\(loopCount)End")
                loopCount += 1
                
                builder.buildBr(loopHead)
                
                builder.positionAtEnd(of: loopHead)
                let memPtr = builder.buildInBoundsGEP(memory, indices: [IntType.int16.zero(), builder.buildLoad(dataPointer)])
                let memVal = builder.buildLoad(memPtr)
                let cond = builder.buildICmp(memVal, IntType.int8.zero(), IntPredicate.equal)
                builder.buildCondBr(condition: cond, then: loopEnd, else: loopStart)
                
                builder.positionAtEnd(of: loopStart)
                
                irLoop(nodes, builder, memory, dataPointer, main, &loopCount)
                builder.buildBr(loopHead)
                builder.positionAtEnd(of: loopEnd)
            case .outputChar:
                let memPtr = builder.buildInBoundsGEP(memory, indices: [IntType.int16.zero(), builder.buildLoad(dataPointer)])
                let charVal = builder.buildLoad(memPtr)
                _ = builder.buildCall(putcFunc!, args: [charVal])
            default:
                break
            }
        }
    }
    
    func emitIR(_ ast: [BfAstNode]) {
        let builder = IRBuilder(module: module)
        
        // Main function to hold BF compiled code
        let main = builder.addFunction("main", type: FunctionType(argTypes: [], returnType: IntType.int64))
        
        let entry = main.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entry)
        
        // Create memory array, size 65535
        let memory = builder.buildAlloca(type: ArrayType(elementType: IntType.int8, count: 0xFFFF))
        
        let dataPointer = builder.buildAlloca(type: IntType.int16)
        
        // Initially zero memPtr
        builder.buildStore(IntType.int16.zero(), to: dataPointer)
        var loopCount = 0
        
        let putcFuncSig = FunctionType(argTypes: [IntType.int8], returnType: VoidType())
        putcFunc = builder.addFunction("putchar", type: putcFuncSig)

        irLoop(ast, builder, memory, dataPointer, main, &loopCount)
        builder.buildRet(IntType.int64.constant(0))
        module.dump()
        
        //LLVMLinkInInterpreter()
//        let jit = try! JIT(module: module, machine: TargetMachine())
//
//        _ = jit.runFunction(main, args: [])
        
        let passManager = FunctionPassManager(module: module)
        passManager.add(.instructionCombining, .reassociate, .gvn, .cfgSimplification, .deadStoreElimination, .aggressiveDCE)
        passManager.run(on: main)
        
        let target = try! TargetMachine(triple: nil, cpu: "", features: "", optLevel: .aggressive, relocMode: .default, codeModel: .default)
        try! target.emitToFile(module: module, type: .assembly, path: "/Users/andybest/Desktop/bf-opt.s")
        
        try! module.emitBitCode(to: "/Users/andybest/Desktop/bf.bc")
    }
}
