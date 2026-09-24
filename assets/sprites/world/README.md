# Arte da caverna subaquática

Assets bitmap criados com a ferramenta integrada de geração de imagens e importados como texturas do Godot. O jogo usa os sete PNGs abaixo. No Godot, `pixel_asset_cache.gd` reduz chão e trilha para 16×16 pixels lógicos; paredes, água e relíquia para 32×32; o atlas para 64×64 (quatro sprites de 32×32); e o portão para 96×64. O filtro `nearest` mantém pixels nítidos; a etapa em memória fixa a opacidade das texturas de terreno e reduz tons intermediários. O shader `cave_pool_ripple.gdshader` move discretamente as poças em passos de um pixel. O cache `.godot/` é recriado pelo editor.

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
