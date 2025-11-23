**This is a collection of some of my freelance work in Godot 4**

The included samples feature three of the systems I created as part of my contract. This is not a full demo project -- many pieces are omitted and some parts of the code cannot function without them. This repository is meant to showcase my coding and software design style.

**1) CompositeSprite2D**

This component is designed to solve the problem of animating character sprites that are made of multiple layers, in order to support character customization (such as separate layers for the head, hair, body, etc.). It was set up to behave just like Godot's AnimatedSprite2D as far as our animation controller code is concerned, which made it a simple drop-in replacement.


**2) Interact System**

These components allow designers to easily add objects that the player can interact with in the multiplayer environment. Actions the player can perform are represented as child nodes of InteractableArea, and when the player selects one, server side logic can be added to react to the signals emitted by InteractAction.


**3) Save Manager**

This singleton lays the groundwork for easy saving and loading of the game state.



**All rights reserved by Ashenthorne Atelier L.L.C.. See LICENSE.txt for more information**


