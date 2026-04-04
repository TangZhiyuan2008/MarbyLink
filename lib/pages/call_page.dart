import 'package:flutter/material.dart';
import 'package:marbylink/models/call.dart';
import 'package:marbylink/network/call_manager.dart';
class CallPage extends StatefulWidget {
  final Call call;
  final CallManager callManager;
  final bool isIncoming;
  const CallPage({
    super.key,
    required this.call,
    required this.callManager,
    required this.isIncoming,
  });
  @override
  State<CallPage> createState() => _CallPageState();
}
class _CallPageState extends State<CallPage> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  @override
  void initState() {
    super.initState();
  }
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }
  void _answerCall() {
    widget.callManager.answerCall(widget.call.id);
  }
  void _endCall() {
    widget.callManager.endCall(widget.call.id);
    Navigator.pop(context);
  }
  void _rejectCall() {
    widget.callManager.rejectCall(widget.call.id);
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.isIncoming ? '来电' : '呼叫中',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 32),
            Text(
              widget.call.type == CallType.voice ? '语音通话' : '视频通话',
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 64),
            if (widget.call.type == CallType.video) ...[
              Container(
                width: 200,
                height: 300,
                color: Colors.grey[800],
                child: const Center(
                  child: Text('视频画面', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
            ],
            Text(
              widget.isIncoming ? '来自: ${widget.call.callerId}' : '呼叫: ${widget.call.receiverId}',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 128),
            if (widget.isIncoming) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: GestureDetector(
                      onTap: _rejectCall,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                        child: const Center(
                          child: Icon(Icons.call_end, size: 40, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: GestureDetector(
                      onTap: _answerCall,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                        child: const Center(
                          child: Icon(Icons.call, size: 40, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                        ),
                        child: Center(
                          child: Icon(
                            _isMuted ? Icons.mic_off : Icons.mic,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                        child: const Center(
                          child: Icon(Icons.call_end, size: 40, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: _toggleSpeaker,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                        ),
                        child: Center(
                          child: Icon(
                            _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}