import 'package:flutter/material.dart';
import '../models/kategori_modeli.dart';

class KategoriKartiWidget extends StatelessWidget {
  final KategoriModeli kategori;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDuzenle;
  final VoidCallback onSil;
  final VoidCallback? onAltKategoriler;

  const KategoriKartiWidget({
    Key? key,
    required this.kategori,
    required this.onTap,
    required this.onLongPress,
    required this.onDuzenle,
    required this.onSil,
    this.onAltKategoriler,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hexToColor(kategori.renkKodu).withOpacity(0.1),
                _hexToColor(kategori.renkKodu).withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              // Ana içerik
              Row(
                children: [
                  // Kategori simgesi
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _hexToColor(kategori.renkKodu).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(
                        _getIconData(kategori.simgeKodu),
                        color: _hexToColor(kategori.renkKodu),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Kategori bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kategori adı
                        Text(
                          kategori.kategoriAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Belge sayısı
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${kategori.belgeSayisi ?? 0} belge',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        // Açıklama (varsa)
                        if (kategori.aciklama != null &&
                            kategori.aciklama!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            kategori.aciklama!,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Alt kategori göstergesi
                        if (kategori.altKategoriVarMi) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${kategori.altKategoriler!.length} alt kategori',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Menü butonu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onSelected: (value) {
                      switch (value) {
                        case 'duzenle':
                          onDuzenle();
                          break;
                        case 'alt_kategoriler':
                          if (onAltKategoriler != null) onAltKategoriler!();
                          break;
                        case 'sil':
                          onSil();
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'duzenle',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 12),
                                Text('Düzenle'),
                              ],
                            ),
                          ),
                          if (kategori.anaKategoriMi)
                            const PopupMenuItem(
                              value: 'alt_kategoriler',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open, size: 18),
                                  SizedBox(width: 12),
                                  Text('Alt Kategoriler'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'sil',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 18),
                                SizedBox(width: 12),
                                Text(
                                  'Sil',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),

              // Alt kategori hızlı erişim (varsa)
              if (kategori.altKategoriVarMi &&
                  kategori.altKategoriler!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: kategori.altKategoriler!.length,
                    itemBuilder: (context, index) {
                      final altKategori = kategori.altKategoriler![index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Chip(
                          avatar: Icon(
                            _getIconData(altKategori.simgeKodu),
                            size: 16,
                            color: _hexToColor(altKategori.renkKodu),
                          ),
                          label: Text(
                            altKategori.kategoriAdi,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: _hexToColor(
                            altKategori.renkKodu,
                          ).withOpacity(0.1),
                          side: BorderSide(
                            color: _hexToColor(
                              altKategori.renkKodu,
                            ).withOpacity(0.3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  IconData _getIconData(String iconCode) {
    switch (iconCode) {
      case 'description':
        return Icons.description;
      case 'image':
        return Icons.image;
      case 'videocam':
        return Icons.videocam;
      case 'music_note':
        return Icons.music_note;
      case 'archive':
        return Icons.archive;
      case 'folder':
        return Icons.folder;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'bookmark':
        return Icons.bookmark;
      case 'label':
        return Icons.label;
      case 'category':
        return Icons.category;
      default:
        return Icons.folder;
    }
  }
}
