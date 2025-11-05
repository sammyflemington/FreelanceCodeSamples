**This is a collection of some of my freelance work in Godot 4**

The included samples feature three of the systems I created as part of my contract. This is not a full demo project -- many pieces are omitted and some parts of the code cannot function without them. This repository is meant to showcase my coding and software design style.

**1) CompositeSprite2D**

This component is meant to behave like Godot's included AnimatedSprite2D, but adds the ability to animate a character that is split into parts, such as having separate layers for the head and body, which allows for easy implementation of character customization. It is also designed to accomodate characters facing different directions (up, down, left, and right), because the game it was created for is a top-view 2D game.


**2) Interact System**

These components allow designers to easily add objects that the player can interact with in the multiplayer environment. Actions the player can perform are represented as child nodes of InteractableArea, and when the player selects one, server side logic can be added to react to the signals emitted by InteractAction.


**3) Save Manager**

This singleton lays the groundwork for easy saving and loading of the game state.



**NOTE: All code in this repository is owned by Ashenthorne Atelier L.L.C. and is showcased with permission and for demonstration purposes only. See LICENSE.txt for more information.**
