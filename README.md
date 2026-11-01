# hs

Szybkie menu sesji [Herdr](https://herdr.sh): lista, otwórz/utwórz, attach, stop, usuń. Jeden skrypt bash, bez python3 i node.

## Instalacja

```bash
curl -fsSL https://raw.githubusercontent.com/bartlomiejszwakop/herdr-hs/main/install.sh | sh
```

Kładzie `hs` w `~/.local/bin` (albo `/usr/local/bin`, jeśli odpalasz jako root). Potrzebny `herdr` na PATH.

Aktualizacja: ta sama komenda.

## Użycie

```bash
hs                 # menu (numer = otwórz sesję)
hs 5               # otwórz sesję nr 5
hs platforma       # otwórz lub utwórz sesję o tej nazwie
hs list            # lista
hs open [nazwa]    # otwórz / utwórz
hs attach [nazwa]  # dołącz
hs stop <nazwa>    # zatrzymaj
hs delete <nazwa>  # usuń (najpierw stop, jeśli działa)
```

W menu: numer = otwórz, `n` = nowa, `a` = attach, `s` = stop, `d` = usuń, `x` = stop+usuń, `q` = wyjście.

Sesji `default` nie usuwa. Stop `default` wymaga wpisania nazwy.
