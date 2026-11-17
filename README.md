# YouTube Music для Omarchy

Мини-плеер YouTube Music в верхней панели Omarchy: обложка и название, управление воспроизведением, перемотка, очередь и альбомы, перемешивание и повтор. Маленькая карточка плавно раскрывается в полный плеер. Цвета подстраиваются под тему.

## Установка

Нужны Omarchy с Quickshell (проверено на 4.0.6), Opera GX и Python с `aiohttp`. Установщик при необходимости установит пакет `python-aiohttp` через Omarchy.

```bash
curl -fsSL https://raw.githubusercontent.com/6axam/omarchy-youtube-music/main/install.sh | bash
```

Затем один раз создай запускатель браузера:

```bash
bash ~/.config/omarchy/plugins/6axam.youtube-music/setup-browser.sh
```

Закрой Opera GX и запусти её командой, которую напечатает скрипт. Открой YouTube Music в боковой панели или вкладке. Для работы плеера браузер нужно запускать через созданный запускатель; обычный запуск браузера не включает подключение.

Если открыто несколько сессий YouTube Music, нужную можно выбрать внизу раскрытого плеера. Выбор запоминается.

## Доступ к браузеру

Запускатель включает Chrome DevTools на `127.0.0.1:9222`. Любая локальная программа, способная подключиться к этому порту, может управлять браузером и получать доступ к данным его вкладок. Используй запускатель только в доверенной среде. Плагин работает с открытой страницей `music.youtube.com`, не запрашивает пароль и не отправляет данные на собственный сервер.

## Обновление и удаление

```bash
omarchy plugin update 6axam.youtube-music
systemctl --user restart omarchy-youtube-music.service
omarchy restart shell
```

Чтобы отключить интеграцию:

```bash
bash ~/.config/omarchy/plugins/6axam.youtube-music/uninstall.sh
omarchy plugin remove 6axam.youtube-music
```

Профиль браузера не удаляется. В плагине использованы компоненты Omarchy по лицензии MIT; см. [LICENSE](LICENSE).
