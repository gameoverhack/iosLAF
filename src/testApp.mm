#include "testApp.h"

//--------------------------------------------------------------
void testApp::setup(){
	
    // open UDP broadcast port
    UDPbroadcast.Create();
    UDPbroadcast.Bind(10001);
    UDPbroadcast.SetNonBlocking(true);
    
    sampleRate = 60.0;
    
	//force landscape oreintation
	ofSetOrientation(OF_ORIENTATION_90_RIGHT);
    
    //    motion.setUseDeviceMotion(false);
    motion.setSampleRate(sampleRate);
    motion.start();
    
    //    ofSetFrameRate(sampleRate);
    
    bShowInfo = false;
    bShowHistory = true;
    
    // setup simple buttons
    float tSize = (float)ofGetHeight() / 4.0;
    
    btnReset.setup(ofGetWidth() - tSize, tSize * 0, tSize, tSize, "reset");
    btnShowHistory.setup(ofGetWidth() - tSize, tSize * 1, tSize, tSize, "history");
    btnShowInfo.setup(ofGetWidth() - tSize, tSize * 2, tSize, tSize, "info");
    btnRate.setup(ofGetWidth() - tSize, tSize * 3, tSize, tSize, "rate");
    btnRecord.setup(0, 0, tSize * 2, ofGetHeight(), "record");
    
    btnReset.setToggle(true);
    btnRecord.setToggle(true);
    btnRate.setToggle(true);
    btnShowHistory.setState(true);
    
    bOscIsSetup = bYarpIsSetup = bUdpIsSetup = false;
    
	ofBackground(0, 0, 0);
    
    // determine client IP addresse and root
    clientIPfull = getIPAddress();
    clientIProot = clientIPfull.substr(0, clientIPfull.rfind("."));
    clientID = ofToInt(clientIPfull.substr(clientIPfull.rfind(".") + 1, string::npos));
    serverIPfull = ""; // nothing until we get a ping from the server on x.x.x.255
    
}

//--------------------------------------------------------------
void testApp::update(){
    
    char udpBroadcastMessageChar[1024];
    UDPbroadcast.Receive(udpBroadcastMessageChar, 1024);
    string udpBroadcastMessageStr = udpBroadcastMessageChar;
    
    if(udpBroadcastMessageStr != ""){
        
        cout << "UDP Broadcast Message: " << udpBroadcastMessageStr << endl;
        
        vector<string> command = ofSplitString(udpBroadcastMessageStr, "_");
        
        // setup IP address for server
        if(command[0] == "S" && serverIPfull == ""){
            
            serverIPfull = clientIProot + "." + command[1];
            ofLogNotice() << "Connecting to server at: " << serverIPfull;
            
            string msg = "C_" + ofToString(clientID);
            UDPbroadcast.Send(msg.c_str(), msg.size());
            
            // connect OSC
            ofLogNotice() << "Connecting to OSC server at: " << serverIPfull << ":" << 10003 << endl;
            oscSender.setup(serverIPfull, 10003);
            bOscIsSetup = true;
            
            // connect YARP
            ofLogNotice() << "Connecting to YARP nameserver at: " << serverIPfull << ":" << 10003 << endl;
            
            yarp::os::impl::NameConfig nameConfig;
            nameConfig.setManualConfig(serverIPfull.c_str(), 10000);
            
            string clientIDs = "/iOSClient"+ofToString(clientID);
            
            ofLogNotice() << "Connecting to YARP port at: " << clientIDs << ":" << 10003 << endl;
            
            bYarpIsSetup = port.open(clientIDs.c_str());
            yarp::os::NetworkBase::connect(clientIDs.c_str(), "/motionReceiver");
            
            // connect UDP
            
        }
        
    }
    
    if(!motion.getIsDataNew()) return;
    
    ofPoint acceleration = motion.getAcceleration();
    ofPoint rotation = motion.getRotation();
    ofPoint gravity = motion.getGravity();
    ofPoint attitude = motion.getAttitude();
    ofPoint uacceleration = motion.getAccelerationWithoutGravity();
    //    ofPoint iacceleration = motion.getAccelerationInstaneous();
    
    if(bShowHistory){
        
        float tSize = (float)ofGetHeight() / 3.0;
        
        if(accelerationHistory.size() > ofGetWidth() - (int)tSize) accelerationHistory.clear();
        if(rotationHistory.size() > ofGetWidth() - (int)tSize) rotationHistory.clear();
        if(attitudeHistory.size() > ofGetWidth() - (int)tSize) attitudeHistory.clear();
        
        accelerationHistory.push_back(uacceleration);
        rotationHistory.push_back(rotation);
        attitudeHistory.push_back(attitude);
        
    }
    
    DeviceMessage dm;
    
    dm.clientID =       clientID;
    dm.deviceType =     PHONETYPE_IPHONE;
    dm.serverType =     SERVERTYPE_MATTG;
    dm.timestamp =      ofGetElapsedTimeMillis();
    dm.accelerationX =  acceleration.x;
    dm.accelerationY =  acceleration.y;
    dm.accelerationZ =  acceleration.z;
    dm.rotationX =      rotation.x;
    dm.rotationY =      rotation.y;
    dm.rotationZ =      rotation.z;
    dm.attitudeX =      attitude.x;
    dm.attitudeY =      attitude.y;
    dm.attitudeZ =      attitude.z;
    dm.gravityX =       gravity.x;
    dm.gravityY =       gravity.y;
    dm.gravityZ =       gravity.z;
    dm.uaccelerationX = uacceleration.x;
    dm.uaccelerationY = uacceleration.y;
    dm.uaccelerationZ = uacceleration.z;
    
    //sendOSC(dm);
    sendYarp(dm);
    
//    ostringstream osmsg;
//    osmsg << "P_";
//    osmsg << clientID << "_";
//    osmsg << PHONETYPE_IPHONE << "_";
//    osmsg << SERVERTYPE_MATTG << "_";
//    osmsg << ofGetElapsedTimeMillis() << "_";
//    osmsg << acceleration.x << "_";
//    osmsg << acceleration.y << "_";
//    osmsg << acceleration.z << "_";
//    osmsg << rotation.x << "_";
//    osmsg << rotation.y << "_";
//    osmsg << rotation.z << "_";
//    osmsg << attitude.x << "_";
//    osmsg << attitude.y << "_";
//    osmsg << attitude.z << "_";
//    osmsg << gravity.x << "_";
//    osmsg << gravity.y << "_";
//    osmsg << gravity.z << "_";
//    osmsg << uacceleration.x << "_";
//    osmsg << uacceleration.y << "_";
//    osmsg << uacceleration.z << "_";
//    
//    UDPbroadcast.Send(osmsg.str().c_str(), osmsg.str().size());
//    cout << osmsg << endl;
//    cout << osmsg.str().size() << endl;
//
//    return;
    
    
    
}

//--------------------------------------------------------------
void testApp::sendOSC(DeviceMessage& dm){
    
    if(!bOscIsSetup) return;
    
    cout << "send osc" << endl;
    
    ofxOscMessage m;
    m.setAddress("/device");
    
    m.addIntArg(dm.clientID);
    m.addIntArg(dm.deviceType);
    m.addIntArg(dm.serverType);
    
    m.addIntArg(dm.timestamp);
    
    m.addFloatArg(dm.accelerationX);
    m.addFloatArg(dm.accelerationY);
    m.addFloatArg(dm.accelerationZ);
    
    m.addFloatArg(dm.rotationX);
    m.addFloatArg(dm.rotationY);
    m.addFloatArg(dm.rotationZ);
    
    m.addFloatArg(dm.attitudeX);
    m.addFloatArg(dm.attitudeY);
    m.addFloatArg(dm.attitudeZ);
    
    m.addFloatArg(dm.gravityX);
    m.addFloatArg(dm.gravityY);
    m.addFloatArg(dm.gravityZ);
    
    m.addFloatArg(dm.uaccelerationX);
    m.addFloatArg(dm.uaccelerationY);
    m.addFloatArg(dm.uaccelerationZ);
    
    oscSender.sendMessage(m);
}

//--------------------------------------------------------------
void testApp::sendYarp(DeviceMessage& dm){
    
    if (!bYarpIsSetup) return;
    
    cout << "send yarp" << endl;
    
    yarp::os::Bottle *output;
    output = &port.prepare();
    output->clear();
    
    output->addString("/device");
    
    output->addInt(dm.clientID);
    output->addInt(dm.deviceType);
    output->addInt(dm.serverType);
    
    output->addInt(dm.timestamp);
    
    output->addDouble(dm.accelerationX);
    output->addDouble(dm.accelerationY);
    output->addDouble(dm.accelerationZ);
    
    output->addDouble(dm.rotationX);
    output->addDouble(dm.rotationY);
    output->addDouble(dm.rotationZ);
    
    output->addDouble(dm.attitudeX);
    output->addDouble(dm.attitudeY);
    output->addDouble(dm.attitudeZ);
    
    output->addDouble(dm.gravityX);
    output->addDouble(dm.gravityY);
    output->addDouble(dm.gravityZ);
    
    output->addDouble(dm.uaccelerationX);
    output->addDouble(dm.uaccelerationY);
    output->addDouble(dm.uaccelerationZ);
    
    port.write();
    
}

//--------------------------------------------------------------
void testApp::sendUDP(DeviceMessage& dm){
    
}

//--------------------------------------------------------------
void testApp::draw(){
    
    btnReset.draw();
    btnShowHistory.draw();
    btnShowInfo.draw();
    btnRate.draw();
    btnRecord.draw();
    
    if(btnShowInfo.getState()){
        
        ofSetColor(255, 255, 255);
        
        ostringstream os;
        os << "FPS: " << ofGetFrameRate() << endl;
        os << motion.getSensorDataAsString() << endl;
        ofDrawBitmapString(os.str(), 20, 20);
        
    }
    
    if(btnShowHistory.getState()){
        drawVector(0, (ofGetHeight() / 3.0f) * 0 + 30, 20, accelerationHistory, "acceleration");
        drawVector(0, (ofGetHeight() / 3.0f) * 1 + 30, 20, rotationHistory, "rotation");
        drawVector(0, (ofGetHeight() / 3.0f) * 2 + 30, 20, attitudeHistory, "attitude");
    }
    
}

//--------------------------------------------------------------
void testApp::drawVector(float x, float y, float scale, vector<ofPoint> & vec, string label){
    if(vec.size() < 2) return;
    
    ofEnableSmoothing();
    ofEnableAlphaBlending();
    ofSetLineWidth(1.0f);
    
    ofMesh meshX;
    ofMesh meshY;
    ofMesh meshZ;
    
    meshX.setMode(OF_PRIMITIVE_LINE_STRIP);
    meshY.setMode(OF_PRIMITIVE_LINE_STRIP);
    meshZ.setMode(OF_PRIMITIVE_LINE_STRIP);
    
    ofPushMatrix();
    ofTranslate(x, y);
    ofNoFill();
    ofSetColor(255, 255, 255);
    
    ofDrawBitmapString(label, 20.0f, -20.0f);
    
    for(int dx = 0; dx < vec.size() - 1; dx++){
        meshX.addColor(ofColor(255,0,0));
        meshX.addVertex(ofVec2f(dx + x, vec[dx].x * scale + y));
        
        meshY.addColor(ofColor(0,255,0));
        meshY.addVertex(ofVec2f(dx + x, vec[dx].y * scale + y + scale));
        
        meshZ.addColor(ofColor(0,0,255));
        meshZ.addVertex(ofVec2f(dx + x, vec[dx].z * scale + y + 2*scale));
    }
    
    ofPopMatrix();
    
    meshX.draw();
    meshY.draw();
    meshZ.draw();
}

//--------------------------------------------------------------
void testApp::exit(){
    
}

//--------------------------------------------------------------
void testApp::touchDown(ofTouchEventArgs & touch){
    
    btnReset.mousePressed(touch.x, touch.y);
    btnShowHistory.mousePressed(touch.x, touch.y);
    btnShowInfo.mousePressed(touch.x, touch.y);
    btnRate.mousePressed(touch.x, touch.y);
    btnRecord.mousePressed(touch.x, touch.y);
    
    if(btnRecord.getState()){
        
        ofxOscMessage m;
        m.setAddress("/record");
        m.addIntArg(clientID);
        m.addIntArg(PHONETYPE_IPHONE);
        m.addIntArg(SERVERTYPE_MATTG);
        m.addIntArg(ofGetElapsedTimeMillis());
        m.addIntArg(1);
        oscSender.sendMessage(m);
    }
    
    if(btnReset.getState()){
        
        motion.calibrate();
        
        ofxOscMessage m;
        m.setAddress("/reset");
        m.addIntArg(clientID);
        m.addIntArg(PHONETYPE_IPHONE);
        m.addIntArg(SERVERTYPE_MATTG);
        m.addIntArg(ofGetElapsedTimeMillis());
        oscSender.sendMessage(m);
        
    }
    
    if (btnRate.getState()){
        
        sendRateSkip++;
        
        if(sendRateSkip > 4){
            sendRateSkip = 1;
        }
        
        printf("sendrateskip=%i\n", sendRateSkip);
        
        ofSetFrameRate(60/sendRateSkip);
        motion.setSampleRate(60/sendRateSkip);
    }
}

//--------------------------------------------------------------
void testApp::touchMoved(ofTouchEventArgs & touch){
    //    sampleRate =  60.0 * touch.y / (float)ofGetHeight();
    //    motion.setSampleRate(sampleRate);
    //    ofSetFrameRate(sampleRate);
}

//--------------------------------------------------------------
void testApp::touchUp(ofTouchEventArgs & touch){
    
    bool bIsRecording = btnRecord.getState();
    
    btnReset.mouseReleased(touch.x, touch.y);
    btnShowHistory.mouseReleased(touch.x, touch.y);
    btnShowInfo.mouseReleased(touch.x, touch.y);
    btnRecord.mouseReleased(touch.x, touch.y);
    btnRate.mouseReleased(touch.x, touch.y);
    
    return; //ignore OSC
    
    if(bIsRecording && !btnRecord.getState()){
        
        ofxOscMessage m;
        m.setAddress("/record");
        m.addIntArg(clientID);
        m.addIntArg(PHONETYPE_IPHONE);
        m.addIntArg(SERVERTYPE_MATTG);
        m.addIntArg(ofGetElapsedTimeMillis());
        m.addIntArg(0);
        oscSender.sendMessage(m);
        
    }
}

//--------------------------------------------------------------
void testApp::touchDoubleTap(ofTouchEventArgs & touch){
    //    if(touch.x < ofGetWidth()/2.0f) bShowInfo = !bShowInfo;
    //    if(touch.x > ofGetWidth()/2.0f) bShowHistory = !bShowHistory;
}

//--------------------------------------------------------------
void testApp::touchCancelled(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void testApp::lostFocus(){
    
}

//--------------------------------------------------------------
void testApp::gotFocus(){
    
}

//--------------------------------------------------------------
void testApp::gotMemoryWarning(){
    
}

//--------------------------------------------------------------
void testApp::deviceOrientationChanged(int newOrientation){
    
}

//--------------------------------------------------------------
string testApp::getIPAddress(){
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    string wifiAddress = "";
    string cellAddress = "";
    
    // retrieve the current interfaces - returns 0 on success
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            sa_family_t sa_type = temp_addr->ifa_addr->sa_family;
            if(sa_type == AF_INET || sa_type == AF_INET6) {
                string name = temp_addr->ifa_name;
                string addr = inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr); // pdp_ip0
                cout << "NAME: " << name << " ADDR: " << addr << endl;
                if(name == "en0" || name == "en1") {
                    // Interface is the wifi connection on the iPhone
                    wifiAddress = addr;
                } else
                    if(name == "pdp_ip0") {
                        // Interface is the cell connection on the iPhone
                        cellAddress = addr;
                    }
            }
            temp_addr = temp_addr->ifa_next;
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    string addr = wifiAddress != "" ? wifiAddress : cellAddress;
    return addr != "" ? addr : "0.0.0.0";
}
