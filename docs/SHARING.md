# Как поделиться модами

## 1. Доступ к приватному репозиторию

Репозиторий приватный: видишь только ты. Чтобы дать доступ другу: репозиторий на GitHub, Settings, Collaborators, Add people. Друг клонирует репозиторий и ставит моды:

```
git clone https://github.com/0d1ns0n/zomboid-mods.git
cd zomboid-mods
python tools/install.py
```

Скрипт копирует папки из `mods` в `%UserProfile%\Zomboid\mods`. Дальше включить моды в игре и перезапустить её.

## 2. Архивы для друзей

```
python tools/package.py
```

В папке `dist` появятся архивы вида `ALifeCamp-0.5.zip`. Внутри папка мода: её нужно распаковать в `%UserProfile%\Zomboid\mods`. Архив можно отправить любым способом или приложить к релизу на GitHub:

```
gh release create alifecamp-0.5 dist/ALifeCamp-0.5.zip --title "ALifeCamp 0.5" --notes-file CHANGELOG.md
```

## 3. Steam Workshop

Загрузка идёт из самой игры, под твоим Steam-аккаунтом, поэтому её делаешь только ты.

1. Собери заготовку: `python tools/package.py workshop ALifeCamp`. Появится `dist/Workshop/ALifeCamp` с файлом `workshop.txt` и папкой `Contents/mods/ALifeCamp`.
2. Скопируй папку `dist/Workshop/ALifeCamp` в `%UserProfile%\Zomboid\Workshop`.
3. Положи рядом с `workshop.txt` файл `preview.png`: квадрат, лучше 256 на 256 и меньше 1 МБ.
4. В `workshop.txt` проверь название, описание и теги. Видимость сначала оставь `private`.
5. В игре: главное меню, Workshop, создать или обновить предмет, выбери эту папку. После первой загрузки Steam назначит предмету номер, который запишется в `workshop.txt` как `id=`.
6. Открой страницу предмета, проверь, потом поменяй видимость на «только друзья» или «публично». В описании укажи требуемые предметы: Project A-Life NPCs (для ALifeCamp и ALifeRU), ALifeCamp (для ALifeCampCheats).

Каждый мод загружается отдельным предметом. CheatPanelPX без разрешения MrZoloto выкладывать не стоит: он дополняет его мод.

## 4. Если захочешь сделать репозиторий публичным

* Добавь файл `LICENSE` (для кода подойдёт MIT, если не нужно ничего запрещать).
* Проверь чужое: переводы Project A-Life в ALifeRU и всё, что связано с Cheat Menu от MrZoloto. Попроси разрешения у авторов или убери эти части.
* Добавь скриншоты в README.
* Только потом: Settings, General, Danger Zone, Change visibility.
