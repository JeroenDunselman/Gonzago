//
//  Conductor.swift
//  Swipe-O-Phone
//
//  Created by Jeroen Dunselman on 20/03/2019.
//  Copyright © 2019 Jeroen Dunselman. All rights reserved.
//

import Foundation
import UIKit
import AudioKit

protocol Conductable {
    func phraseEnded()
    func chordChanged()
    func visualizePlaying(position: CGPoint, velocity: CGFloat) //, chordVariant: Int)
}

class Conductor {
    
    let orchestra = AudioService()
    var triggerEnabled = true
    
    var timerNoteOff: Timer?
    let releaseTime: Double = 0.5
    var currentVelocity: CGPoint = CGPoint(x: 0, y: 0)
    
    let chords = NoteNumberService()
    var currentNote:Int = 64
    var chordIndex = 0
    var chordVariant = 0
    
    var octaveZonesCount = 3 //limited notes in scale
    var octaveIndex = 0
    var fourFingerTranspose = 0 //transposes - 1
    
    let sequence:[Int] = [0, 1, 2, 1, 3, 2, 0, 1]
    var sequenceIndex = 0
    
    let client: ViewController
    init(_ swipeVC: ViewController) {
        client = swipeVC
    }
    
    @objc func gestureAction(_ sender:UIPanGestureRecognizer) {
        let pos = sender.location(in: client.view)
        let velocity = sender.velocity(in: client.view)
        
        handleNumberOfTouches(sender)
        handlePan(pos: pos)
        
            //next phrase
        if triggerEnabled {
            self.playNextNote()
            triggerEnabled = false
            client.chordChanged()
        }

            //detect change of direction of pan
        if((velocity.y > 0 && currentVelocity.y < 0) || (velocity.y < 0 && currentVelocity.y > 0)) {
            //transport sequence to next note for changed direction and play it
            sequenceIndex += 1
            self.playNextNote()
        }
            //update current
        currentVelocity.y = velocity.y
        
            //prepare note release
        //accomplish continuous postponement of NoteOff event while still panning
        if !(timerNoteOff == nil) {
            //cancel previous noteOff
            timerNoteOff?.invalidate()
            timerNoteOff = nil
        }
        //accomplish continuous reset of timer to invoke noteOff after releaseTime after pan ends
        self.timerNoteOff = Timer.scheduledTimer(timeInterval: releaseTime, target:self, selector: #selector(self.triggerNoteOffEvent), userInfo: nil, repeats: true)
    }
    
    func handleNumberOfTouches(_ sender:UIPanGestureRecognizer) {
        
        if (sender.numberOfTouches == 4) {
            fourFingerTranspose = -1;
            self.chordVariant = 0
        } else {
            fourFingerTranspose = 0;
            self.chordVariant = max(sender.numberOfTouches  - 1, 0)
        }
    }
    
    func handlePan(pos: CGPoint) {

        let chordFromLocation = min(
            Int((pos.x/client.view.bounds.size.width) * CGFloat(chords.numberOfRegions)),
            chords.numberOfRegions - 1)
        
        //chord changes
        if chordIndex != chordFromLocation {
            chordIndex = chordFromLocation
            client.chordChanged()
        }
        
        //oct changes
        let octaveFromLocation = Int((pos.y / client.view.bounds.size.height) * CGFloat(octaveZonesCount))
        if (octaveIndex != octaveFromLocation) {
            octaveIndex = octaveFromLocation
        }
        
        //animate
        let someAsYetUnexplainedLimiterValue = 16
        let velocity: CGFloat = currentVelocity.y / CGFloat(someAsYetUnexplainedLimiterValue)
        client.visualizePlaying(position: pos, velocity: velocity)
    }
    
    @objc func triggerNoteOffEvent() {
        timerNoteOff?.invalidate()
        timerNoteOff = nil
//        allNotesOff()
        sequenceIndex = 0
        triggerEnabled = true
        
        client.phraseEnded()
    }
    
    func playNextNote() {
        //        noteOff(note: MIDINoteNumber(currentNote))
        
        //loop sequence
        if sequenceIndex >= sequence.count { sequenceIndex = 0 }
        
        var octave = 0
        if octaveIndex == 0 {octave = -12}
        if octaveIndex == 2 {octave = 12}
        currentNote = octave + 40 + chords.scales[self.chordVariant][self.chordIndex][sequence[sequenceIndex]] + fourFingerTranspose
        //        print("currentNote: \(currentNote)")
        noteOn(note: MIDINoteNumber(currentNote))
    }
    
    func noteOn(note: MIDINoteNumber) {
        orchestra.play(noteNumber: note)
    }
    
    //not in use for plucked instrument
    //    //    func noteOff(note: MIDINoteNumber) {    }
    //
    //    func allNotesOff() {
    //    //        _ = (0..<128).map { noteOff(note: MIDINoteNumber($0)) }
    //    }
    
}


