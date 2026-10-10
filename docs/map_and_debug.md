# Mapa e ferramentas de debug

## Carta da gruta

M ou o botão Mapa abre o mapa completo, ajustado aos limites reais do blueprint.
M, Esc ou Voltar fecha. O jogo pausa enquanto o mapa está aberto; abrir a partir
da pausa mantém a pausa ao fechar. A roda amplia até 8×, arrastar move a carta,
e Ver tudo restaura o enquadramento inicial. No TP, arraste com o botão direito.

As regiões desconhecidas ficam escuras. Caminhar revela as células próximas;
uma região descoberta permanece clara até terminar ou reiniciar a partida.
Paredes, água e portões bloqueiam a exposição das salas além deles. A carta
marca o jogador, o trajeto, chaves descobertas e portões. TP não traça uma linha
de caminhada entre salas distantes. A iluminação ambiente da caverna é preservada.

## Debug oculto

Segure Ctrl, H e J simultaneamente, em qualquer ordem, para abrir/fechar o painel.
Esc e Fechar também fecham. F3 e iniciar com --debug não exibem ferramentas.
O painel fica oculto ao iniciar; não há botão de debug no HUD.

1. **Testar árvore:** adiciona 1000 XP temporários e abre a árvore real, com os
   mesmos custos e pré-requisitos. As compras afetam o personagem para testar
   combate. Durante esse teste, XP e habilidades não são gravados no save.
   Restaurar progresso real devolve o saldo e habilidades anteriores; sair ou
   reiniciar a fase também restaura. Fechar o painel mantém o teste ativo.
2. **Teleportar:** abre a carta em modo TP. Clique em chão livre para mudar de
   posição, mesmo em salas distantes. Rejeita água, rochas, bordas, portões
   fechados, personagens mortos e habilidades ainda em andamento. Atualiza
   câmera e exploração sem contar o deslocamento como progresso de movimento.
3. **Mapa revelado:** alterna uma visualização integral para inspecionar a fase.
   Desligá-la recupera a exploração real; não grava áreas fictícias como visitadas.

Menus respeitam a pausa anterior. Debug aguarda terminar diálogos e apresentações
que bloqueiam controles. Testes não modificam a progressão real em user://progression.cfg.

## Validação

`tools/validators/map_debug_test.gd` cobre acorde de três teclas, ausência em F3,
mapa/pausa, coordenadas, exploração, três ferramentas, compras sem alteração do
save, restauração ao sair, destinos inválidos e layouts 640×360, 1152×648 e 800×1000.
Com DROWNED_MAP_CAPTURE=1, salva capturas em .godot/map_debug_review/.
