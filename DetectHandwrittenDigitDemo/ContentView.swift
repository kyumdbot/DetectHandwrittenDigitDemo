//
//  ContentView.swift
//  DetectHandwrittenDigitDemo
//
//  Created by Wei-Cheng Ling on 2020/12/21.
//

import SwiftUI

struct ContentView: View {
    @State private var digit1 : Int?
    @State private var digit2 : Int?
    
    var body: some View {
        VStack {
            HStack {
                CameraView(digit: $digit1)
                    .frame(width: 640, height: 480, alignment: .center)
                    .background(Color.black)
                    .border(Color(white: 0.85), width: 1)
                
                CameraView(digit: $digit2)
                    .frame(width: 640, height: 480, alignment: .center)
                    .background(Color.black)
                    .border(Color(white: 0.85), width: 1)
            }
            
            Spacer()
                .frame(height: 35)
            
            ZStack {
                Text("\( (digit1 ?? 0) + (digit2 ?? 0)) ")
                    .frame(width: 140, height: 140, alignment: .center)
                    .font(.custom("Courier", size: 58))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.blue)
                    .background(Color.white)
                    .cornerRadius(70)
                
                Text("Sum")
                    .font(.custom("Courier", size: 30))
                    .foregroundColor(Color(.sRGB, red: 0, green: 128/255, blue: 1, opacity: 1)  )
                    .offset(x: 0, y: -69)
            }
            
            Spacer()
                .frame(height: 40)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
