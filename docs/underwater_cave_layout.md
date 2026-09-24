# Planta da caverna

A planta é autoral e está salva em `scenes/world/areas/underwater_cave.tscn`, propriedade `map_layout` de `UnderwaterCave`. Cada caractere representa uma célula do piso; as paredes são instâncias apenas nas bordas, e os tiles usam os PNGs de `assets/sprites/world/`.

## Legenda

| Símbolo | Função |
| --- | --- |
| `s`, `p`, `c`, `b`, `e` | Origem, trilha, seção de combate, arena do chefe e trecho de saída. |
| `~`, `r`, `a` | Lagoa não transitável, rocha não transitável e alga decorativa. |
| `I` | Relíquia opcional coletável; três posições nas ramificações. |
| `P`, `T`, `L` | Entrada do jogador, foco do tutorial e três ecos narrativos. |
| `C`, `M`, `D`, `B`, `E` | Gatilho de combate, sete pontos de inimigos, foco da revelação, chefe e saída. |
| `1`, `2`, `3` | Travessias bloqueadas até a conclusão da exploração, das ondas e da luta com o chefe. |

O corredor principal serpenteia do início até a arena final; ramificações secundárias retornam ao eixo e incluem água, obstáculos e itens. A saída desce da arena, atravessa um portão de ferro laranja e termina no marcador `E`. O mapa conserva a lógica de combate e os personagens existentes; somente os pontos `M` foram reposicionados.

Colisões: paredes, rochas e portões recebem corpos estáticos; a validação de caminhada também rejeita água, rochas e portões fechados. O mapa foi checado com `tools/validators/map_world_smoke_test.gd` e `combat_smoke_test_v2.gd`.
