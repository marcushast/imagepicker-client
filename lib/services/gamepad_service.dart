import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gamepads/gamepads.dart';

/// Service for handling gamepad input events and translating them to application actions.
///
/// This service listens to gamepad events from the `gamepads` plugin and invokes
/// callback functions for various actions. It includes debouncing, analog threshold
/// detection, dead zone handling, and button combination support.
class GamepadService {
  StreamSubscription<GamepadEvent>? _subscription;
  DateTime _lastInputTime = DateTime.now();
  static const Duration _debounceDuration = Duration(milliseconds: 100);
  static const double _analogThreshold = 0.5;
  static const double _deadZone = 0.2;
  static const Duration _exitComboDuration = Duration(milliseconds: 500);

  // Button state tracking for combinations
  bool _selectPressed = false;
  bool _startPressed = false;
  DateTime? _comboPressStart;

  // Analog stick state tracking (for debouncing stick inputs)
  DateTime _lastStickInputTime = DateTime.now();

  // Connection state
  bool _isConnected = false;
  String? _connectedGamepadName;

  // Callbacks for actions
  VoidCallback? onPreviousImage;
  VoidCallback? onNextImage;
  VoidCallback? onPickImage;
  VoidCallback? onRejectImage;
  VoidCallback? onClearStatus;
  VoidCallback? onPickWithoutAdvance;
  VoidCallback? onRejectWithoutAdvance;
  VoidCallback? onShowHelp;
  VoidCallback? onOpenFolderPicker;
  VoidCallback? onExitApp;
  VoidCallback? onJumpToFirstUnreviewed;
  VoidCallback? onJumpToNextUnreviewed;

  // Callback for connection state changes
  Function(bool connected, String? gamepadName)? onConnectionChanged;

  bool get isConnected => _isConnected;
  String? get connectedGamepadName => _connectedGamepadName;

  /// Initialize the gamepad service and start listening to events.
  void initialize() {
    _subscription = Gamepads.events.listen(_handleGamepadEvent);
    _checkInitialConnection();
  }

  /// Check if any gamepads are already connected at initialization.
  Future<void> _checkInitialConnection() async {
    final gamepads = await Gamepads.list();
    if (gamepads.isNotEmpty) {
      _isConnected = true;
      _connectedGamepadName = gamepads.first.name;
      onConnectionChanged?.call(true, _connectedGamepadName);
    }
  }

  /// Handle incoming gamepad events.
  void _handleGamepadEvent(GamepadEvent event) {
    // Update connection state
    _updateConnectionState(event);

    // Handle button events
    if (event.type == KeyType.button) {
      _handleButtonEvent(event);
    }

    // Handle analog events (triggers and sticks)
    if (event.type == KeyType.analog) {
      _handleAnalogEvent(event);
    }
  }

  /// Update connection state based on events.
  void _updateConnectionState(GamepadEvent event) {
    final wasConnected = _isConnected;
    final previousName = _connectedGamepadName;

    // Consider connected if we're receiving events
    _isConnected = true;
    _connectedGamepadName = event.gamepadId;

    // Notify if connection state changed
    if (wasConnected != _isConnected || previousName != _connectedGamepadName) {
      onConnectionChanged?.call(_isConnected, _connectedGamepadName);
    }
  }

  /// Handle digital button press events.
  void _handleButtonEvent(GamepadEvent event) {
    final buttonPressed = event.value == 1.0;

    // Track Select and Start button states for exit combination
    if (event.key == 'BTN_SELECT' || event.key == '8') {
      _selectPressed = buttonPressed;
    }
    if (event.key == 'BTN_START' || event.key == '9') {
      _startPressed = buttonPressed;
    }

    // Check for Select + Start combination (exit)
    if (_selectPressed && _startPressed) {
      if (_comboPressStart == null) {
        _comboPressStart = DateTime.now();
      } else {
        final holdDuration = DateTime.now().difference(_comboPressStart!);
        if (holdDuration >= _exitComboDuration) {
          onExitApp?.call();
          _comboPressStart = null; // Reset after triggering
          return;
        }
      }
    } else {
      _comboPressStart = null; // Reset if buttons released
    }

    // Only process button presses (not releases) for most actions
    if (!buttonPressed) return;

    // Check debouncing
    final now = DateTime.now();
    if (now.difference(_lastInputTime) < _debounceDuration) {
      return;
    }

    // Handle individual buttons
    switch (event.key) {
      // Face buttons (using both evdev names and numeric IDs for compatibility)
      case 'BTN_SOUTH':
      case 'BTN_A':
      case '0':
        onPickImage?.call();
        _lastInputTime = now;
        break;

      case 'BTN_EAST':
      case 'BTN_B':
      case '1':
        onRejectImage?.call();
        _lastInputTime = now;
        break;

      case 'BTN_WEST':
      case 'BTN_X':
      case '2':
        onClearStatus?.call();
        _lastInputTime = now;
        break;

      case 'BTN_NORTH':
      case 'BTN_Y':
      case '3':
        onShowHelp?.call();
        _lastInputTime = now;
        break;

      // Bumpers
      case 'BTN_TL':
      case 'BTN_LB':
      case '4':
        onJumpToFirstUnreviewed?.call();
        _lastInputTime = now;
        break;

      case 'BTN_TR':
      case 'BTN_RB':
      case '5':
        onJumpToNextUnreviewed?.call();
        _lastInputTime = now;
        break;

      // D-Pad
      case 'BTN_DPAD_LEFT':
      case '14':
        onPreviousImage?.call();
        _lastInputTime = now;
        break;

      case 'BTN_DPAD_RIGHT':
      case '15':
        onNextImage?.call();
        _lastInputTime = now;
        break;

      case 'BTN_DPAD_UP':
      case '12':
        onPickImage?.call(); // Changed: Pick AND advance
        _lastInputTime = now;
        break;

      case 'BTN_DPAD_DOWN':
      case '13':
        onRejectImage?.call(); // Changed: Reject AND advance
        _lastInputTime = now;
        break;

      // Center buttons
      case 'BTN_SELECT':
      case '8':
        // Only trigger if not part of exit combo
        if (!_startPressed) {
          onOpenFolderPicker?.call();
          _lastInputTime = now;
        }
        break;

      case 'BTN_START':
      case '9':
        // Only trigger if not part of exit combo
        if (!_selectPressed) {
          onShowHelp?.call();
          _lastInputTime = now;
        }
        break;
    }
  }

  /// Handle analog input events (triggers and sticks).
  void _handleAnalogEvent(GamepadEvent event) {
    final now = DateTime.now();

    // Handle triggers (buttons 6 and 7, or axis events)
    if (event.key == 'BTN_TL2' || event.key == '6' || event.key == 'ABS_Z' || event.key == 'LEFT_TRIGGER') {
      if (event.value > _analogThreshold) {
        if (now.difference(_lastInputTime) >= _debounceDuration) {
          onPreviousImage?.call();
          _lastInputTime = now;
        }
      }
      return;
    }

    if (event.key == 'BTN_TR2' || event.key == '7' || event.key == 'ABS_RZ' || event.key == 'RIGHT_TRIGGER') {
      if (event.value > _analogThreshold) {
        if (now.difference(_lastInputTime) >= _debounceDuration) {
          onNextImage?.call();
          _lastInputTime = now;
        }
      }
      return;
    }

    // Handle left stick (for navigation)
    if (event.key == 'ABS_X' || event.key == 'LEFT_ANALOG_STICK_X') {
      if (now.difference(_lastStickInputTime) < _debounceDuration) {
        return;
      }

      if (event.value < -_deadZone) {
        onPreviousImage?.call();
        _lastStickInputTime = now;
      } else if (event.value > _deadZone) {
        onNextImage?.call();
        _lastStickInputTime = now;
      }
      return;
    }

    if (event.key == 'ABS_Y' || event.key == 'LEFT_ANALOG_STICK_Y') {
      if (now.difference(_lastStickInputTime) < _debounceDuration) {
        return;
      }

      if (event.value < -_deadZone) {
        onPickImage?.call(); // Changed: Pick AND advance
        _lastStickInputTime = now;
      } else if (event.value > _deadZone) {
        onRejectImage?.call(); // Changed: Reject AND advance
        _lastStickInputTime = now;
      }
      return;
    }
  }

  /// Dispose of the service and clean up resources.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
