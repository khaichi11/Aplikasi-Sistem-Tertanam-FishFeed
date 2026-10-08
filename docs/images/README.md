# Gambar dokumentasi

- Berkas `01-*.png` hingga `10-*.png` merupakan tangkapan layar aplikasi yang dihasilkan oleh
  `embed/integration_test/screenshots_test.dart` di emulator Android.
- Folder `framed/` berisi tangkapan layar yang sama di dalam bingkai ponsel. Bingkai tersebut digambar sendiri dengan
  skrip `tool/phone_frame.py` dari repo [MEIRA](https://github.com/khaichi11/MEIRA) (Apache-2.0), misalnya
  `python3 tool/phone_frame.py <folder>/framed <folder>/[01][0-9]-*.png --width 300 --no-status-bar`.
- Berkas `architecture.png`, `feed-flow.png`, `wiring.png`, dan `data-structure.png` merupakan diagram yang dihasilkan
  oleh `tools/make_diagrams.py`.
- Berkas `logo.png` adalah logo aplikasi yang dihasilkan oleh `embed/tool/generate_icons.py`.

Gambar sebaiknya tidak disunting secara manual; jalankan ulang skrip pembuatnya bila perlu diperbarui.
