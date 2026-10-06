# Afogados e Guardião Abissal

Folhas geradas com a ferramenta de imagens integrada (skill imagegen), usando
Mergulhador e Quebra-Mar como referências visuais. O Guardião usa também o Afogado
como referência: mesma espécie, roupa e paleta; ombros, braços e tronco mais fortes.

Cada atlas possui **6 colunas × 5 linhas**, com seis poses por animação:

1. Repouso.
2. Corrida.
3. Ataque com antecipação, golpe e recuperação.
4. Dano e recuperação.
5. Morte, terminando no corpo caído.

Os PNGs têm transparência real e versões de **64×64 e 96×96 por quadro**.
O jogo usa a versão de 96 px, como os personagens atuais; o Afogado fica em
escala 1 e o Guardião em 1,5. A versão de 64 px está disponível para uso menor.
A direção horizontal é espelhada em runtime. As poses não incluem oito direções.

As folhas *_sheet_source.png preservam a geração original. O importador
tools/enemy_sprite_pipeline.gd detecta os espaços entre poses, remove pequenos
fragmentos que invadiram células vizinhas, registra os pés e reduz com nearest
neighbor. Recrie com:

    godot --headless --path . --script res://tools/enemy_sprite_pipeline.gd
    godot --headless --editor --path . --import

Prompts finais (normalizados; referências e restrições abaixo):

- **Afogado:** sprite sheet de pixel art para Drowned. Zumbi marinho humanoide,
  pele verde-azulada dessaturada, uniforme naval azul escuro rasgado, cinto e botas
  marrons, algas, cracas nos ombros e olhos ciano claros. Sem arma. Mesmo estilo,
  contornos pretos, proporções e nível de detalhe dos personagens de referência;
  vista lateral em três quartos voltada à direita. Seis poses de repouso, seis de
  corrida com pernas alternadas, seis de ataque de garras com antecipação e
  recuperação, seis de dano, seis de morte até cair e permanecer deitado. Grade
  6×5, poses isoladas, tamanho e identidade constantes, pés alinhados, margens
  transparentes. Fundo RGBA transparente, sem sombras, texto, rótulos ou grade.
- **Guardião Abissal:** mesma espécie e uniforme do Afogado, com ombros muito
  largos, braços musculosos, peito robusto e punhos grandes. Mesma paleta
  verde-azulada, azul naval, marrom, ocre e olhos ciano. Algas e cracas nos ombros.
  Sem arma gigante, chifres ou nova estética. Mesmos contornos e proporções das
  referências. Grade 6×5: seis repousos, seis corridas pesadas, seis ataques
  de soco/esmagamento, seis danos e seis mortes até o corpo caído. Silhueta,
  roupa e tamanho constantes; poses dentro das células; transparência real;
  sem cenário, texto, grade ou efeitos de névoa.

Os efeitos de impacto são desenhados pelo Godot. Os sons curtos de golpe,
deslocamento, dano e morte são sintetizados em gameplay_feedback.gd.
