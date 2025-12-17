# ABSTRACT: General viewer for rich text content

use Terminal::Widgets::Layout;
use Terminal::Widgets::WrappableBuffer;


#| Layout node for a rich text viewer widget
class Terminal::Widgets::Layout::RichTextViewer
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'rich-text-viewer' }
}


#| General viewer for rich text content
class Terminal::Widgets::Viewer::RichText
 does Terminal::Widgets::WrappableBuffer {
    method layout-class() { Terminal::Widgets::Layout::RichTextViewer }
}


# Register Viewer::RichText as a buildable widget type
Terminal::Widgets::Viewer::RichText.register;
