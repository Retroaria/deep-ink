# Deep Ink — histórico de versões

Cada versão vira uma pré-release própria no GitHub, com os APKs:
- **deep-ink-arm.apk**: celulares antigos / 32 bits (ex.: LG F100, F200, F300)
- **deep-ink-arm64.apk**: celulares modernos

Funciona a partir do Android 4.3. Os ajustes do Deep Immersion (DI) ficam na aba **Deep Ink**, o primeiro ícone do menu de cima (o "p" com a gota).

## Beta 4 — 2026-11-24

- **Aba própria do Deep Ink no menu de cima:** o primeiro ícone (o "p" com a gota de tinta) reúne todas as opções do Deep Immersion, sem precisar entrar em Configurações.
- **Piscada mais leve e mais rápida:** em vez de inverter a tela (o que deixava as letras brancas e perfeitas), a página escurece pela metade por cerca de 0,05 s. As letras mantêm a textura.
- **Fantasmas removidos:** o rastro da página anterior ficava legível demais em áreas em branco e atrapalhava a leitura.

## Beta 3 — 2026-11-24

- **Piscada de atualização (o "carregar" do e-ink):** em viradas de página aleatórias, a tela pisca invertida por um instante antes da página nova. Frequência em *Page refresh flash*: Off, Rare (12–20 páginas), Normal (6–12, padrão) ou Frequent (2–5).
- **Fantasmas (ghosting):** um rastro leve da página anterior fica na tela até a próxima piscada. Intensidade em *Ghosting*, de 0 a 100% (padrão 40%).
- **Tom do papel de 1 a 5:** em *Paper shade*, do 1 (mais claro) ao 5 (mais escuro). Padrão 3, mais escuro que antes.
- *Paper tone* agora muda só a tonalidade: cinza e-ink, neutro ou quente.
- Resolução simulada padrão passou a ser **167 ppi**, a que funcionou melhor no LG F200.

## Beta 2 — 2026-11-24

- Ícone do Deep Ink corrigido: a variante do Android usada sobrepunha o ícone do KOReader.
- Deep Immersion **ligado por padrão**, com aviso na primeira abertura mostrando onde fica o menu.
- Nova opção de resolução simulada: **130 ppi (efeito forte)**, para telas de densidade mais baixa.

## Beta 1 — 2026-11-24

- Primeira versão do **Deep Immersion (DI)**, baseada no KOReader: resolução simulada (300, 220 ou 167 ppi), 4/8/16 tons de cinza com dithering, espalhamento da tinta nas bordas das letras, grão e tom do papel.
- Ação *Toggle Deep Immersion* para associar a um gesto e comparar com a tela normal.
- App próprio ("Deep-Ink"), que instala ao lado do KOReader, com pasta de dados separada.
