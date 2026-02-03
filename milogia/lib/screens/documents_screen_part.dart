  Widget _buildMyDocumentsView(Map<String, Color> theme) {
      if (_groupedDocuments.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off, size: 60, color: Colors.grey),
              const SizedBox(height: 10),
              Text(L10n.labelNoDocsFound(context), style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groupedDocuments.length,
        itemBuilder: (context, index) {
          final grado = _groupedDocuments.keys.elementAt(index);
          final docs = _groupedDocuments[grado]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  grado == 0 ? L10n.labelGeneralDocs(context) : '${L10n.labelGradePrefix(context)} $grado',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: theme['accent']
                  ),
                ),
              ),
              ...docs.map((doc) => _buildDocumentCard(doc)),
            ],
          );
        },
      );
  }
