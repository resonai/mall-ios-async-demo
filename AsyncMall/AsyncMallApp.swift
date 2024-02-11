//
//  AsyncMallApp.swift
//  AsyncMall
//
//  Created by Alex Culeva on 11.02.2024.
//

import SwiftUI
import AsyncAlgorithms
import Combine

@main
struct AsyncMallApp: App {

    let mall = TestMall()
    @State var tasks = Set<VoidTask>()
    @State var startDate = Date()
//    @State var bag = Set<AnyCancellable>()

    var body: some Scene {
        WindowGroup {
            VStack {
                ContentView()
                    .onAppear {
                        tasks = mall.register()
                        Task {
                            for await value in await mall.b300.subscribe().dropFirst() {
                                print("Time: ", Date().timeIntervalSince(startDate))
                            }
                        }
//                        bag = mall.prepare()
//                        mall.b300.dropFirst().sink { _ in
//                            print("Time: ", Date().timeIntervalSince(startDate))
//                        }.store(in: &bag)
                    }
                Button(action: {
                    startDate = Date()
//                    mall.b0.send(true)
                    Task {
                        await mall.b0.send(true)
                    }
                }, label: {
                    Text("Trigger")
                })
            }

        }
    }
}
