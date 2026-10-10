# Ritmo do prólogo

A partida alterna pequenos confrontos no caminho, três ondas com composição distinta, escolha de melhorias e o Guardião. Movimento abre a primeira passagem após 220 unidades; corrida, ataque e os três ecos deixam de ser requisitos para prosseguir. A narrativa inicial e a apresentação do chefe continuam no fluxo.

## Controles e decisões

- WASD / setas: mover; Ctrl: correr; **Shift: esquiva** de 0,18 s, invulnerável, com recarga de 1,1 s. Não atravessa paredes nem portões e não interrompe ataques ou especiais.
- Segure Espaço / J / clique esquerdo para continuar atacando na cadência do personagem. Q / botão direito mantém o especial independente.
- **E perto de um eco** investiga a história opcional, cura 10 e recarrega o especial. Requer caminho livre de inimigos; os ecos podem ser encontrados em qualquer ordem.
- Um pequeno indicador junto ao personagem segue os corredores e mostra a direção do próximo confronto, do chefe ou da saída.

## Encontros e recompensas

Duas emboscadas curtas ocupam o caminho até a câmara, e uma pequena guarda intercepta a aproximação ao fosso do chefe. Os inimigos da câmara aparecem perto do jogador, em piso aberto, com aviso de 0,7 s que congela na pausa. As ondas têm 4, 5 e 6 inimigos:

| Inimigo | Comportamento | Resposta do jogador |
| --- | --- | --- |
| Afogado | Persegue e anuncia golpes próximos | Acertar, afastar e usar área |
| Caçador | Mais rápido, menos vida, investida com faixa de aviso | Esquivar lateralmente; golpes interrompem a preparação |
| Pesado | Mais vida, movimento lento, golpe forte com antecipação longa | Aproveitar a abertura após o golpe; juntar alvos para o especial |

A cada dois inimigos comuns derrotados cai um brilho verde. Recolher a até 58 unidades recupera 5 de vida e reduz a recarga do especial em 0,8 s. Expira após 14 s e respeita paredes e pausa: é preciso buscar a posição do inimigo derrotado.

Após as duas primeiras ondas, o jogador recupera 12% de vida e o especial fica pronto. A próxima onda aguarda uma escolha:

- Primeira recompensa: +20% de dano em ataques e especiais **ou** especial com recarga 20% menor.
- Segunda recompensa: +20% de dano **ou** +25% de vida máxima com cura equivalente ao aumento.

As melhorias acumulam apenas durante a partida; reiniciar restaura os atributos. Ao terminar a terceira onda, 20% de vida são recuperados e o especial fica pronto para o chefe. A revelação usa movimentos de câmera mais curtos. O resultado registra tempo jogado, inimigos derrotados e melhorias escolhidas. O Guardião continua exigindo uma chave-bússola para abrir a saída.

## Verificação

`tools/validators/gameplay_rhythm_test.gd` cobre esquiva nos três perfis, dano bloqueado, portões, recarga e pausa, ataque mantido, avanço sem ecos obrigatórios, emboscadas, avisos pausáveis, coleta, composição das ondas, escolhas sem duplicação e transição até a saída. `combat_smoke_test_v2.gd` mantém a regressão do prólogo completo. Capturas das escolhas: execute o teste com renderer e `DROWNED_RHYTHM_CAPTURE=1`; saída em `.godot/rhythm_review/`.
