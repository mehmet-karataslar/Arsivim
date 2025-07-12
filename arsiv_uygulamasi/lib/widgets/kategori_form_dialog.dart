import 'package:flutter/material.dart';
import '../models/kategori_modeli.dart';
import '../widgets/renk_secici_widget.dart';
import '../widgets/simge_secici_widget.dart';
import '../services/log_servisi.dart';

class KategoriFormDialog extends StatefulWidget {
  final KategoriModeli? kategori; // null ise yeni kategori, değilse düzenleme

  const KategoriFormDialog({Key? key, this.kategori}) : super(key: key);

  @override
  State<KategoriFormDialog> createState() => _KategoriFormDialogState();
}

class _KategoriFormDialogState extends State<KategoriFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  final LogServisi _logServisi = LogServisi.instance;

  // Form kontrolleri
  final _kategoriAdiController = TextEditingController();
  final _aciklamaController = TextEditingController();

  // Seçim durumları
  String _secilenRenk = '#2196F3';
  String _secilenSimge = 'folder';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Düzenleme modunda mevcut değerleri yükle
    if (widget.kategori != null) {
      _kategoriAdiController.text = widget.kategori!.kategoriAdi;
      _aciklamaController.text = widget.kategori!.aciklama ?? '';
      _secilenRenk = widget.kategori!.renkKodu;
      _secilenSimge = widget.kategori!.simgeKodu;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kategoriAdiController.dispose();
    _aciklamaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.kategori != null ? Icons.edit : Icons.add,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.kategori != null
                        ? 'Kategori Düzenle'
                        : 'Yeni Kategori',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: 'Bilgiler', icon: Icon(Icons.info_outline)),
                Tab(text: 'Renk', icon: Icon(Icons.palette)),
                Tab(text: 'Simge', icon: Icon(Icons.emoji_symbols)),
              ],
            ),
            const SizedBox(height: 16),

            // Tab içerikleri
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBilgilerTab(),
                  _buildRenkTab(),
                  _buildSimgeTab(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Aksiyon butonları
            Row(
              children: [

                // İptal butonu
                Flexible(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 4),

                // Kaydet butonu
                Flexible(
                  child: ElevatedButton(
                    onPressed: _kaydet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.kategori != null ? 'Güncelle' : 'Kaydet',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBilgilerTab() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kategori adı
            TextFormField(
              controller: _kategoriAdiController,
              decoration: InputDecoration(
                labelText: 'Kategori Adı *',
                hintText: 'Kategori adını girin',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kategori adı gereklidir';
                }
                if (value.trim().length < 2) {
                  return 'Kategori adı en az 2 karakter olmalıdır';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Açıklama
            TextFormField(
              controller: _aciklamaController,
              decoration: InputDecoration(
                labelText: 'Açıklama (İsteğe Bağlı)',
                hintText: 'Kategori hakkında kısa açıklama',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenkTab() {
    return SingleChildScrollView(
      child: RenkSeciciWidget(
        secilenRenk: _secilenRenk,
        onRenkSecildi: (renk) {
          setState(() {
            _secilenRenk = renk;
          });
        },
      ),
    );
  }

  Widget _buildSimgeTab() {
    return SingleChildScrollView(
      child: SimgeSeciciWidget(
        secilenSimge: _secilenSimge,
        onSimgeSecildi: (simge) {
          setState(() {
            _secilenSimge = simge;
          });
        },
      ),
    );
  }

  void _kaydet() {
    final kategoriAdi = _kategoriAdiController.text.trim();

    // Manuel validasyon - kategori adı kontrolü
    if (kategoriAdi.isEmpty) {
      // Bilgiler tab'ına geç ve hata göster
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori adı gereklidir'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (kategoriAdi.length < 2) {
      // Bilgiler tab'ına geç ve hata göster
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori adı en az 2 karakter olmalıdır'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _logServisi.debug('Kategori adı: "$kategoriAdi"');
    _logServisi.debug('Kategori adı boş mu: ${kategoriAdi.isEmpty}');

    final kategori = KategoriModeli(
      id: widget.kategori?.id,
      kategoriAdi: kategoriAdi,
      renkKodu: _secilenRenk,
      simgeKodu: _secilenSimge,
      aciklama:
          _aciklamaController.text.trim().isEmpty
              ? null
              : _aciklamaController.text.trim(),
      olusturmaTarihi: widget.kategori?.olusturmaTarihi ?? DateTime.now(),
    );

    _logServisi.debug('Kategori toMap: ${kategori.toMap()}');
    Navigator.of(context).pop(kategori);
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  IconData _getIconData(String iconCode) {
    // Simge seçici widget'ındaki aynı mantık
    const simgeler = [
      {'kod': 'folder', 'icon': Icons.folder},
      {'kod': 'description', 'icon': Icons.description},
      {'kod': 'image', 'icon': Icons.image},
      {'kod': 'videocam', 'icon': Icons.videocam},
      {'kod': 'music_note', 'icon': Icons.music_note},
      {'kod': 'archive', 'icon': Icons.archive},
      {'kod': 'work', 'icon': Icons.work},
      {'kod': 'school', 'icon': Icons.school},
      {'kod': 'home', 'icon': Icons.home},
      {'kod': 'favorite', 'icon': Icons.favorite},
      {'kod': 'star', 'icon': Icons.star},
      {'kod': 'bookmark', 'icon': Icons.bookmark},
      {'kod': 'label', 'icon': Icons.label},
      {'kod': 'category', 'icon': Icons.category},
      {'kod': 'shopping_cart', 'icon': Icons.shopping_cart},
      {'kod': 'restaurant', 'icon': Icons.restaurant},
      {'kod': 'sports_soccer', 'icon': Icons.sports_soccer},
      {'kod': 'travel_explore', 'icon': Icons.travel_explore},
      {'kod': 'health_and_safety', 'icon': Icons.health_and_safety},
      {'kod': 'savings', 'icon': Icons.savings},
      {'kod': 'pets', 'icon': Icons.pets},
      {'kod': 'directions_car', 'icon': Icons.directions_car},
      {'kod': 'build', 'icon': Icons.build},
      {'kod': 'lightbulb', 'icon': Icons.lightbulb},
    ];

    final simge = simgeler.firstWhere(
      (s) => s['kod'] == iconCode,
      orElse: () => {'icon': Icons.folder},
    );
    return simge['icon'] as IconData;
  }
}
