# Arch Linux Docker Compose izinlerini kalici duzeltme

Bu repo Docker Compose kaynak kodu. Senin sistemdeki asil sorun Compose kodundan degil, Docker Engine socket izninden geliyor:

- `docker compose version` calisiyor.
- `docker version` istemci bilgisini gosteriyor ama `/var/run/docker.sock` icin `permission denied` veriyor.
- Kullanici `murat`, `docker` grubunda degil.
- Docker socket normalde `root:docker` ve `0660` olmali; sistemde socket `nobody:nobody` gorunuyor.

Bu yuzden Docker komutlari surekli `sudo`, parola veya yetki istiyor. Kalici cozum: Docker paketleri kurulu olacak, servis acik olacak, kullanici `docker` grubunda olacak, socket sahipligi duzelecek, Docker bridge/NAT icin kernel ayarlari kalici yazilacak.

## Tek komut

Repo kokunde calistir:

```bash
sudo bash scripts/fix-arch-docker-compose-permissions.sh murat
```

Sonra oturumu tamamen kapatip ac. Kapatmak istemezsen gecici olarak:

```bash
newgrp docker
```

## Kontrol

```bash
id
docker version
docker compose version
docker run --rm hello-world
```

`id` ciktisinda `docker` grubu gorunmeli. `docker version` artik `permission denied while trying to connect to the docker API` dememeli.

## Format sonrasi hizli kurulum

Yeni Arch/Pacman kurulumunda once repoyu ac, sonra:

```bash
sudo pacman -Syu --needed docker docker-compose docker-buildx iptables-nft
sudo systemctl enable --now docker.service
sudo bash scripts/fix-arch-docker-compose-permissions.sh "$USER"
newgrp docker
docker run --rm hello-world
```

## Neyi degistiriyor?

- `docker`, `docker-compose`, `docker-buildx`, `iptables-nft` paketlerini kurar.
- `docker` grubunu olusturur.
- Kullanici hesabini `docker` grubuna ekler.
- `docker.service` servisini kalici etkinlestirir ve baslatir.
- Varsa `/var/run/docker.sock` sahipligini `root:docker`, iznini `0660` yapar.
- `kernel.unprivileged_userns_clone`, inotify limitleri, bridge netfilter ve IPv4 forwarding ayarlarini `/etc/sysctl.d/` altina kalici yazar.

## Guvenlik notu

`docker` grubuna giren kullanici Docker daemon uzerinden root yetkisine denk guce sahip olur. Bu senin makinen ve sen bilincli olarak parola/sudo istemeden Docker kullanmak istedigin icin bu tercih dogru cozumdur. Paylasimli veya guvenilmeyen kullanicili makinelerde ayni ayar uygulanmamalidir.
