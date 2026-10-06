# Arte da caverna subaquática

Assets bitmap criados com a ferramenta integrada de geração de imagens e importados como texturas do Godot. O jogo reutiliza os sete PNGs abaixo, sem modificar as fontes. No Godot, `pixel_asset_cache.gd` prepara chão, trilha, paredes, água, chave-bússola e portão em 64×64 pixels lógicos; o atlas usa 128×128 (quatro sprites de 64×64). As escalas dos objetos compensam a resolução para preservar seu tamanho no mundo. O filtro `nearest` mantém pixels nítidos; a etapa em memória fixa a opacidade das texturas de terreno e conserva 25 níveis por canal. O shader `cave_pool_ripple.gdshader` move discretamente as poças em passos de um pixel. O cache `.godot/` é recriado pelo editor.

As paredes usam o perímetro da grade escalonada simplificado com tolerância de 52 pixels de mundo, revestido com a textura de 64×64 e uma borda iluminada contínua. Isso elimina a silhueta de losangos isolados nas diagonais; as colisões dos tiles são preservadas. O portão laranja usa duas metades da mesma textura que se recolhem para os lados e permanecem visíveis depois da abertura. As três bússolas existentes funcionam como chaves: qualquer uma abre o portão ao se aproximar após derrotar o Guardião.

| Arquivo atual | Direção final do prompt |
| --- | --- |
| `cave_floor_pixel32.png` | Chão de caverna azul-ardósia, visão de cima, 5–8 manchas grandes, paleta curta, sem grão ou pedrinhas. |
| `cave_path_pixel32.png` | Trilha de sedimento compactado um pouco mais clara e quente que o chão; poucas manchas largas, sem detalhes finos. |
| `cave_wall_pixel32.png` | Basalto azul-escuro, 3–5 faces angulosas grandes e fissuras simples, sem microtextura. |
| `cave_pool_pixel32.png` | Água azul-petróleo escura, faixas largas e só alguns reflexos em pixels grossos, sem espuma. |
| `cave_props_pixel_atlas.png` | Atlas 2×2 transparente: alga turquesa, rochas azul-cinza, coral azul discreto e estalagmite escura; sprites separados e simples. |
| `orange_iron_gate_pixel.png` | Grade larga de ferro laranja enferrujado, poucas barras grossas e silhueta escura, sem gravações finas. |
| `compass_relic_pixel.png` | Bússola coletável de latão e turquesa, silhueta redonda simples e agulha de quatro pontas, sem microdetalhes. |

Todos os prompts pediram pixels quadrados duros, poucas cores chapadas, sem suavização, gradientes, 3D, pintura digital, texto ou marca d’água. Os objetos isolados pediram transparência real.

Modo de geração: novos bitmaps pelo gerador integrado, um prompt separado para cada linha da tabela; sem edição de imagens preexistentes. As cópias originais da geração permanecem no diretório de imagens geradas pelo Codex.
