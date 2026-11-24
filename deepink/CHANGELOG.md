# Deep Ink — histórico de versões

Cada versão vira uma pré-release própria no GitHub, com os APKs:
- **deep-ink-arm.apk**: celulares antigos / 32 bits (ex.: LG F100, F200, F300)
- **deep-ink-arm64.apk**: celulares modernos

Funciona a partir do Android 4.3. Os ajustes do Deep Immersion (DI) ficam na aba **Deep Ink**, o primeiro ícone do menu de cima (o "p" com a gota).

## Beta 6 — 2026-11-24

- **Tela de bloqueio do Deep Ink:** ao apagar a tela com o Deep Ink aberto, a tela do Deep Ink (logo, frase e créditos, em tons de cinza) aparece por cima do bloqueio do Android quando o aparelho é ligado de novo. Deslize ou toque para desbloquear (PIN ou digital, se houver) e voltar ao livro. O livro só aparece depois do desbloqueio. Pode ser desligada em *Deep Ink lock screen*.
- O botão Power continua funcionando como sempre: o Android não permite que apps o interceptem.

## Beta 5 — 2026-11-24

- **Transição de página como no Kindle:** ao virar a página, as letras da página antiga se desfazem em fragmentos enquanto as novas surgem, misturadas por um instante (três quadros rápidos). Pode ser desligada em *Page turn transition*.
- **Piscada cinza, não preta:** a piscada de atualização agora é um cinza médio com o texto invertido bem apagado, como no Kindle, e dura um pouco mais (cerca de 0,08 s) para ser percebida. Ela acontece junto com a transição.

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
