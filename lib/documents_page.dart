import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class DocumentsPage extends StatefulWidget {
  @override
  _DocumentsPageState createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final List<Map<String, dynamic>> _documents = [
    {'name': 'Aadhar Card', 'icon': Icons.credit_card, 'color': Colors.blue},
    {'name': 'PAN Card', 'icon': Icons.account_balance_wallet, 'color': Colors.green},
    {'name': 'Driver License', 'icon': Icons.drive_eta, 'color': Colors.orange},
    {'name': 'Voter ID', 'icon': Icons.how_to_vote, 'color': Colors.purple},
    {'name': 'Photo', 'icon': Icons.photo, 'color': Colors.pink},
  ];

  Map<String, List<String>> _documentImages = {};
  List<Map<String, Object>> _customDocuments = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    String? imagesJson = prefs.getString('document_images');
    String? customDocsJson = prefs.getString('custom_documents');

    if (imagesJson != null) {
      try {
        Map<String, dynamic> imagesMap = json.decode(imagesJson);
        _documentImages = imagesMap.map((key, value) => 
          MapEntry(key, List<String>.from(value)));
      } catch (e) {
        _documentImages = {};
      }
    }

    if (customDocsJson != null) {
      try {
        List<dynamic> customList = json.decode(customDocsJson);
        _customDocuments = customList.map<Map<String, Object>>((item) => {
          'name': item['name'].toString(),
          'icon': Icons.description,
          'color': Colors.teal,
        }).toList();
      } catch (e) {
        _customDocuments = [];
      }
    }
    setState(() {});
  }

  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('document_images', json.encode(_documentImages));
    
    List<Map<String, String>> serializableCustomDocs = _customDocuments.map((doc) => {
      'name': doc['name'].toString(),
    }).toList();
    await prefs.setString('custom_documents', json.encode(serializableCustomDocs));
  }

  void _addCustomDocument() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Custom Document'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Document Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              String name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      print('Adding custom document: $result');
      print('Before add - Custom docs count: ${_customDocuments.length}');
      
      setState(() {
        _customDocuments.add(<String, Object>{
          'name': result,
          'icon': Icons.description,
          'color': Colors.teal,
        });
      });
      
      print('After add - Custom docs count: ${_customDocuments.length}');
      print('Total items in grid: ${_documents.length + _customDocuments.length}');
      
      await _saveDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Custom document "$result" added'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCustomDocumentOptions(int customIndex) {
    String docName = _customDocuments[customIndex]['name'] as String;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom Document Options'),
        content: Text('What would you like to do with "$docName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editCustomDocument(customIndex);
            },
            child: Text('Edit Name'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCustomDocument(customIndex);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editCustomDocument(int customIndex) async {
    String currentName = _customDocuments[customIndex]['name'] as String;
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Document Name'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Document Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              String name = controller.text.trim();
              if (name.isNotEmpty && name != currentName) {
                Navigator.pop(context, name);
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        // Update images map with new name
        if (_documentImages.containsKey(currentName)) {
          _documentImages[result] = _documentImages[currentName]!;
          _documentImages.remove(currentName);
        }
        // Update document name
        _customDocuments[customIndex] = <String, Object>{
          'name': result,
          'icon': Icons.description,
          'color': Colors.teal,
        };
      });
      await _saveDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document renamed to "$result"'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteCustomDocument(int customIndex) {
    String docName = _customDocuments[customIndex]['name'] as String;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Delete "$docName" and all its images?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _customDocuments.removeAt(customIndex);
                _documentImages.remove(docName);
              });
              _saveDocuments();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Document "$docName" deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openDocumentDetail(String docName, IconData icon, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentDetailPage(
          documentName: docName,
          icon: icon,
          color: color,
          images: _documentImages[docName] ?? [],
          onImagesUpdated: (images) {
            setState(() {
              _documentImages[docName] = images;
            });
            _saveDocuments();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Documents'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addCustomDocument,
            tooltip: 'Add Custom Document',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: _documents.length + (_documents.length % 2 == 1 ? 1 : 0) + (_customDocuments.isNotEmpty ? _customDocuments.length + 2 : 0),
          itemBuilder: (context, index) {
            // Add empty space if default documents count is odd
            if (index == _documents.length && _documents.length % 2 == 1) {
              return Container();
            }
            
            // Show custom documents header spanning 2 columns
            int headerIndex = _documents.length + (_documents.length % 2 == 1 ? 1 : 0);
            int adjustment = (_documents.length % 2 == 1 ? 1 : 0) + 2;
            
            if (index == headerIndex && _customDocuments.isNotEmpty) {
              return Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.folder_special, size: 16, color: Colors.teal),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Custom Documents (${_customDocuments.length})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // Empty space for second column of header
            if (index == headerIndex + 1 && _customDocuments.isNotEmpty) {
              return Container();
            }
            
            Map<String, dynamic> doc;
            if (index < _documents.length) {
              doc = _documents[index];
            } else {
              // Adjust index for custom documents (account for spacing and header)
              int customIndex = index - _documents.length - adjustment;
              doc = Map<String, dynamic>.from(_customDocuments[customIndex]);
            }
            int imageCount = _documentImages[doc['name']]?.length ?? 0;
            
            return Card(
              elevation: 4,
              child: InkWell(
                onTap: () => _openDocumentDetail(doc['name'] as String, doc['icon'] as IconData, doc['color'] as Color),
                onLongPress: index > headerIndex + 1 ? () => _showCustomDocumentOptions(index - _documents.length - adjustment) : null,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(doc['icon'] as IconData, size: 32, color: doc['color'] as Color),
                      SizedBox(height: 8),
                      Text(
                        doc['name'] as String,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$imageCount image${imageCount != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class DocumentDetailPage extends StatefulWidget {
  final String documentName;
  final IconData icon;
  final Color color;
  final List<String> images;
  final Function(List<String>) onImagesUpdated;

  DocumentDetailPage({
    required this.documentName,
    required this.icon,
    required this.color,
    required this.images,
    required this.onImagesUpdated,
  });

  @override
  _DocumentDetailPageState createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  late List<String> _images;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.images);
  }

  Future<void> _addImage() async {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Image'),
        content: Text('Choose image source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() {
                  _images.add(image.path);
                });
                widget.onImagesUpdated(_images);
              }
            },
            child: Text('Gallery'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(source: ImageSource.camera);
              if (image != null) {
                setState(() {
                  _images.add(image.path);
                });
                widget.onImagesUpdated(_images);
              }
            },
            child: Text('Camera'),
          ),
        ],
      ),
    );
  }

  void _deleteImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Image'),
        content: Text('Delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _images.removeAt(index);
              });
              widget.onImagesUpdated(_images);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          imagePath: _images[index],
          documentName: widget.documentName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentName),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add_a_photo),
            onPressed: _addImage,
            tooltip: 'Add Image',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 48, color: widget.color),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.documentName,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_images.length} images',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: _images.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No images added yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _addImage,
                            icon: Icon(Icons.add),
                            label: Text('Add Image'),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GestureDetector(
                                  onTap: () => _showFullScreenImage(index),
                                  child: Image.file(
                                    File(_images[index]),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.red,
                                  radius: 16,
                                  child: IconButton(
                                    icon: Icon(Icons.delete, size: 16, color: Colors.white),
                                    onPressed: () => _deleteImage(index),
                                  ),
                                ),
                              ),

                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imagePath;
  final String documentName;

  FullScreenImagePage({required this.imagePath, required this.documentName});

  Future<void> _shareImage() async {
    await Share.shareXFiles([XFile(imagePath)], text: 'Sharing $documentName');
  }

  Future<void> _downloadImage(BuildContext context) async {
    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final fileName = '${documentName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${directory.path}/$fileName';
      
      await File(imagePath).copy(newPath);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image downloaded to Downloads folder'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(documentName),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareImage,
            tooltip: 'Share to WhatsApp',
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _downloadImage(context),
            tooltip: 'Download',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}