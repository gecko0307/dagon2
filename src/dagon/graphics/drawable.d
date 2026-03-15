module dagon.graphics.drawable;

import dagon.graphics.state;

interface Drawable
{
    void render(GraphicsState* state);
}
