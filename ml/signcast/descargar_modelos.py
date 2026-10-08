import urllib.request

from . import config as C


def main():
    C.DIR_MEDIAPIPE.mkdir(parents=True, exist_ok=True)
    for nombre, url in C.URLS_MEDIAPIPE.items():
        destino = C.DIR_MEDIAPIPE / nombre
        if destino.exists():
            print(f"✓ {nombre} ya existe")
            continue
        print(f"↓ {nombre} ...")
        urllib.request.urlretrieve(url, destino)
        print(f"✓ {nombre} ({destino.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
