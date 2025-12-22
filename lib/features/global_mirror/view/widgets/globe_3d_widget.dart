import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/mood_pin_model.dart';

/// 3D Globe widget using WebView with Three.js
class Globe3DWidget extends StatefulWidget {
  final List<MoodPinModel> pins;
  final Function(MoodPinModel)? onPinTap;

  const Globe3DWidget({
    super.key,
    required this.pins,
    this.onPinTap,
  });

  @override
  State<Globe3DWidget> createState() => _Globe3DWidgetState();
}

class _Globe3DWidgetState extends State<Globe3DWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('[Globe3DWidget] JavaScript message: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[Globe3DWidget] Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('[Globe3DWidget] Page finished loading: $url');
            
            // Inject console logging to capture JavaScript errors
            _controller.runJavaScript('''
              (function() {
                var originalLog = console.log;
                var originalError = console.error;
                var originalWarn = console.warn;
                
                console.log = function(...args) {
                  originalLog.apply(console, args);
                  window.Flutter?.postMessage('LOG: ' + args.join(' '));
                };
                
                console.error = function(...args) {
                  originalError.apply(console, args);
                  window.Flutter?.postMessage('ERROR: ' + args.join(' '));
                };
                
                console.warn = function(...args) {
                  originalWarn.apply(console, args);
                  window.Flutter?.postMessage('WARN: ' + args.join(' '));
                };
                
                window.addEventListener('error', function(e) {
                  window.Flutter?.postMessage('JS ERROR: ' + e.message + ' at ' + e.filename + ':' + e.lineno);
                });
              })();
            ''');
            
            setState(() {
              _isLoading = false;
            });
            // Wait longer for Three.js to load and initialize
            Future.delayed(const Duration(milliseconds: 1000), () {
              _updatePins();
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[Globe3DWidget] Web resource error: ${error.description}');
            debugPrint('[Globe3DWidget] Error code: ${error.errorCode}');
            debugPrint('[Globe3DWidget] Error type: ${error.errorType}');
          },
        ),
      )
      ..loadRequest(Uri.dataFromString(_getGlobeHTML(), mimeType: 'text/html'));
  }

  @override
  void didUpdateWidget(Globe3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pins.length != oldWidget.pins.length) {
      _updatePins();
    }
  }

  void _updatePins() {
    if (_isLoading) {
      debugPrint('[Globe3DWidget] Skipping pin update, still loading');
      return;
    }
    
    try {
      if (widget.pins.isNotEmpty) {
        // Build JSON array manually for JavaScript
        final pinsJson = widget.pins.map((pin) => 
          '{lat: ${pin.gridLat}, lon: ${pin.gridLon}, sentiment: "${pin.sentiment}"}'
        ).join(',');
        
        _controller.runJavaScript('''
          try {
            if (typeof window.updatePins === 'function') {
              window.updatePins([$pinsJson]);
              console.log('Updated ${widget.pins.length} pins');
            } else {
              console.warn('updatePins function not available yet');
            }
          } catch (e) {
            console.error('Error updating pins:', e);
          }
        ''');
      } else {
        // Clear pins if empty
        _controller.runJavaScript('''
          try {
            if (typeof window.updatePins === 'function') {
              window.updatePins([]);
              console.log('Cleared all pins');
            }
          } catch (e) {
            console.error('Error clearing pins:', e);
          }
        ''');
      }
    } catch (e) {
      debugPrint('[Globe3DWidget] Error updating pins: $e');
    }
  }

  String _getGlobeHTML() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; overflow: hidden; background: #000; }
    canvas { display: block; width: 100%; height: 100%; }
  </style>
</head>
<body>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script>
    let scene, camera, renderer, globe, pins = []; // pins array now contains objects with {mesh, light}
    let isInitialized = false;
    
    function init() {
      console.log('init() called, THREE available:', typeof THREE !== 'undefined');
      try {
        if (typeof THREE === 'undefined') {
          console.error('THREE is not defined!');
          return;
        }
        
        console.log('Creating scene...');
        scene = new THREE.Scene();
        scene.background = new THREE.Color(0x000000);
        camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(window.devicePixelRatio || 1);
        renderer.setClearColor(0x000000, 1);
        document.body.appendChild(renderer.domElement);
        console.log('Renderer created and added to DOM');
        
        // Create globe with default material first (blue-green sphere)
        console.log('Creating globe geometry...');
        const geometry = new THREE.SphereGeometry(5, 32, 32);
        const defaultMaterial = new THREE.MeshPhongMaterial({ 
          color: 0x2233ff,
          shininess: 30
        });
        globe = new THREE.Mesh(geometry, defaultMaterial);
        scene.add(globe);
        console.log('Globe added to scene');
        
        // Try to load texture, but don't wait for it
        const loader = new THREE.TextureLoader();
        loader.load(
          'https://raw.githubusercontent.com/turban/webgl-earth/master/images/2_no_clouds_4k.jpg',
          // onLoad callback
          (texture) => {
            try {
              const material = new THREE.MeshPhongMaterial({ map: texture, shininess: 30 });
              globe.material = material;
              globe.material.needsUpdate = true;
              console.log('Texture loaded successfully');
            } catch (e) {
              console.error('Error applying texture:', e);
            }
          },
          // onProgress callback
          undefined,
          // onError callback
          (error) => {
            console.warn('Texture failed to load, using default material:', error);
          }
        );
        
        // Add lights
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
        scene.add(ambientLight);
        
        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(5, 5, 5);
        scene.add(directionalLight);
        
        // Position camera
        camera.position.z = 10;
        
        // Add controls (mouse drag to rotate)
        let isDragging = false;
        let previousMousePosition = { x: 0, y: 0 };
        
        renderer.domElement.addEventListener('mousedown', (e) => {
          isDragging = true;
          previousMousePosition = { x: e.clientX, y: e.clientY };
        });
        
        renderer.domElement.addEventListener('mousemove', (e) => {
          if (isDragging && globe) {
            const deltaX = e.clientX - previousMousePosition.x;
            const deltaY = e.clientY - previousMousePosition.y;
            globe.rotation.y += deltaX * 0.01;
            globe.rotation.x += deltaY * 0.01;
            previousMousePosition = { x: e.clientX, y: e.clientY };
          }
        });
        
        renderer.domElement.addEventListener('mouseup', () => {
          isDragging = false;
        });
        
        renderer.domElement.addEventListener('mouseleave', () => {
          isDragging = false;
        });
        
        // Touch controls
        renderer.domElement.addEventListener('touchstart', (e) => {
          e.preventDefault();
          isDragging = true;
          previousMousePosition = { x: e.touches[0].clientX, y: e.touches[0].clientY };
        });
        
        renderer.domElement.addEventListener('touchmove', (e) => {
          e.preventDefault();
          if (isDragging && globe) {
            const deltaX = e.touches[0].clientX - previousMousePosition.x;
            const deltaY = e.touches[0].clientY - previousMousePosition.y;
            globe.rotation.y += deltaX * 0.01;
            globe.rotation.x += deltaY * 0.01;
            previousMousePosition = { x: e.touches[0].clientX, y: e.touches[0].clientY };
          }
        });
        
        renderer.domElement.addEventListener('touchend', (e) => {
          e.preventDefault();
          isDragging = false;
        });
        
        // Handle window resize
        window.addEventListener('resize', () => {
          camera.aspect = window.innerWidth / window.innerHeight;
          camera.updateProjectionMatrix();
          renderer.setSize(window.innerWidth, window.innerHeight);
        });
        
        isInitialized = true;
        console.log('Starting animation loop...');
        // Render immediately
        renderer.render(scene, camera);
        animate();
        console.log('Globe initialized successfully');
      } catch (error) {
        console.error('Error initializing globe:', error);
        console.error('Error stack:', error.stack);
      }
    }
    
    function addPin(lat, lon, sentiment) {
      // Convert lat/lon to 3D coordinates
      const phi = (90 - lat) * (Math.PI / 180);
      const theta = (lon + 180) * (Math.PI / 180);
      const radius = 5.15; // Slightly further from globe surface for better visibility
      
      const x = -(radius * Math.sin(phi) * Math.cos(theta));
      const y = radius * Math.cos(phi);
      const z = radius * Math.sin(phi) * Math.sin(theta);
      
      // Color based on sentiment
      const colors = {
        'positive': 0x00ff00,
        'happy': 0x00ff00,
        'excited': 0x00ff00,
        'calm': 0x0080ff,
        'grateful': 0x0080ff,
        'neutral': 0xffaa00,
        'reflective': 0xffaa00,
        'negative': 0xff0000,
        'sad': 0xff0000,
        'anxious': 0xff0000,
      };
      
      const color = colors[sentiment.toLowerCase()] || 0x888888;
      
      // Make pins MUCH larger and more visible - using a two-part design
      const pinGroup = new THREE.Group();
      
      // Large sphere that sits on the globe surface - much bigger for visibility
      const sphereSize = 0.25; // Significantly larger
      const sphereGeometry = new THREE.SphereGeometry(sphereSize, 16, 16);
      const sphereMaterial = new THREE.MeshPhongMaterial({ 
        color: color,
        emissive: color,
        emissiveIntensity: 1.0, // Full emissive for maximum visibility
        shininess: 100
      });
      const sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
      sphere.position.set(x, y, z);
      pinGroup.add(sphere);
      
      // Add a smaller glowing sphere on top for extra visibility
      const topSphereSize = 0.12;
      const topSphereGeometry = new THREE.SphereGeometry(topSphereSize, 12, 12);
      const topSphereMaterial = new THREE.MeshBasicMaterial({ 
        color: color,
        emissive: color,
        emissiveIntensity: 1.5
      });
      const topSphere = new THREE.Mesh(topSphereGeometry, topSphereMaterial);
      // Position slightly above the main sphere
      const direction = new THREE.Vector3(x, y, z).normalize();
      const topPosition = direction.multiplyScalar(radius + sphereSize + topSphereSize);
      topSphere.position.copy(topPosition);
      pinGroup.add(topSphere);
      
      pinGroup.position.set(0, 0, 0);
      scene.add(pinGroup);
      
      // Add a bright point light for extra visibility
      const pinLight = new THREE.PointLight(color, 1.0, 0.6);
      pinLight.position.set(x, y, z);
      scene.add(pinLight);
      
      pins.push({ mesh: pinGroup, light: pinLight });
      console.log('Added pin at (' + lat + ', ' + lon + ') with color: ' + color.toString(16));
    }
    
    window.updatePins = function(newPins) {
      try {
        if (!scene || !isInitialized) {
          console.warn('Scene not initialized yet, cannot update pins');
          return;
        }
        
        console.log('updatePins called with', newPins ? newPins.length : 0, 'pins');
        
        // Remove old pins (both mesh and light)
        pins.forEach(pinObj => {
          if (pinObj.mesh) scene.remove(pinObj.mesh);
          if (pinObj.light) scene.remove(pinObj.light);
        });
        pins = [];
        
        // Add new pins
        if (newPins && Array.isArray(newPins)) {
          console.log('Adding ' + newPins.length + ' pins to scene');
          newPins.forEach((pin, index) => {
            if (pin && typeof pin.lat === 'number' && typeof pin.lon === 'number') {
              addPin(pin.lat, pin.lon, pin.sentiment || 'neutral');
            } else {
              console.warn('Invalid pin data at index ' + index + ':', pin);
            }
          });
          console.log('Successfully added ' + pins.length + ' pins to scene');
        } else {
          console.log('No pins to add or invalid pin data');
        }
      } catch (e) {
        console.error('Error in updatePins:', e);
        console.error('Error stack:', e.stack);
      }
    };
    
    // Make updatePins available globally
    console.log('updatePins function registered');
    
    function animate() {
      requestAnimationFrame(animate);
      if (globe && isInitialized) {
        globe.rotation.y += 0.001; // Slow rotation
      }
      if (renderer && scene && camera) {
        renderer.render(scene, camera);
      }
    }
    
    // Wait for Three.js to load - use DOMContentLoaded for better reliability
    function waitForThreeJS() {
      if (typeof THREE !== 'undefined') {
        console.log('Three.js is available, initializing...');
        init();
      } else {
        console.log('Three.js not ready yet, waiting...');
        setTimeout(waitForThreeJS, 50);
      }
    }
    
    // Start checking when DOM is ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', waitForThreeJS);
    } else {
      // DOM already loaded, start checking
      waitForThreeJS();
    }
    
    // Also try on window load as backup
    window.addEventListener('load', () => {
      console.log('Window load event fired');
      if (!isInitialized && typeof THREE !== 'undefined') {
        console.log('Initializing from window load event');
        init();
      }
    });
  </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Wrap WebView in error boundary
        Builder(
          builder: (context) {
            try {
              return WebViewWidget(controller: _controller);
            } catch (e) {
              // If WebView fails (e.g., not registered on iOS), show error message
              debugPrint('[Globe3DWidget] WebView error: $e');
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        '3D Globe unavailable',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please rebuild the app to enable 3D globe',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
        if (_isLoading)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Loading 3D Globe...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
