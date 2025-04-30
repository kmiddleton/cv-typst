// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}



#let article(
  title: none,
  authors: none,
  date: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: "1",
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}

#set table(
  inset: 6pt,
  stroke: none
)
#show: doc => article(
  title: [Hello Typst!],
  authors: (
    ( name: [J. Carberry],
      affiliation: [],
      email: [] ),
    ),
  sectionnumbering: "1.1.a",
  toc: true,
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 2,
  doc,
)



#set page(
  paper: "us-letter",
  header: align(right)[
    A fluid dynamic model for
    glacier flow
  ],
  numbering: "1",
)
#set par(justify: true)
#set text(
  font: "Libertinus Serif",
  size: 11pt,
)

= Background 
In the case of glaciers, fluid dynamics principles can be used to understand how the movement and behavior of the ice is influenced by factors such as temperature, pressure, and the presence of other fluids (such as water).
= Introduction
<introduction>
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis eros sed maximus suscipit. Sed faucibus nisl sapien, id molestie ex pellentesque non. Maecenas ultricies risus ullamcorper mauris lacinia, eget feugiat orci aliquam. Morbi fringilla justo eget commodo mattis. Mauris nibh massa, viverra placerat rhoncus a, ultricies in mauris. Ut laoreet aliquet nulla, non lobortis diam pulvinar quis. Pellentesque ornare odio ut lectus molestie elementum. Sed et quam tincidunt, sollicitudin felis at, faucibus sem. Curabitur maximus erat et venenatis sollicitudin. Phasellus aliquet dolor tortor, finibus luctus mauris sollicitudin id.

+ Ut sollicitudin blandit odio eget dapibus. Etiam congue imperdiet sem nec posuere. Nam consequat vitae massa id bibendum.
+ Maecenas semper orci vel tellus mattis volutpat.
  - Sed semper est tortor, nec cursus sapien maximus eget. Praesent cursus hendrerit lacus.
  - Proin ullamcorper auctor ligula. Morbi ligula risus, posuere placerat varius eu, ultrices at arcu. Donec porta metus id nisl porta gravida.

Nulla et egestas metus. Nulla eget tortor id quam tristique fermentum id sit amet eros. Vestibulum ullamcorper velit vel felis ultrices aliquam. Maecenas id diam convallis, elementum quam non, euismod libero. Ut ac varius nisi, non porta sem. Nunc id leo sed metus bibendum lobortis. Nunc feugiat tincidunt ipsum vitae aliquam. Mauris tempor vel libero id eleifend. Ut mattis vel nulla fringilla faucibus.

Etiam neque libero, bibendum vel urna aliquet, convallis mattis nibh. Etiam interdum porttitor ullamcorper. Pellentesque non condimentum turpis. Cras ac mauris at justo posuere dapibus. Nunc faucibus, lectus a pharetra egestas, nibh erat imperdiet velit, ut dapibus diam nisi non eros. Vivamus sem felis, ultricies vitae cursus a, laoreet sed odio. Aliquam eu malesuada velit. Suspendisse molestie sed nulla vel hendrerit. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Fusce porttitor, lorem vel bibendum aliquet, ipsum lectus dapibus eros, non tristique turpis magna quis urna. Fusce eget massa tincidunt, faucibus nisl non, suscipit enim. In dictum eleifend consectetur. Morbi molestie gravida laoreet. Duis sit amet tellus lacinia nulla pulvinar maximus id quis urna.

In elit nisi, iaculis vel cursus vitae, pellentesque eget magna. Maecenas imperdiet arcu et ex commodo pretium. Fusce venenatis venenatis dolor egestas gravida. Phasellus tempus lectus lectus, sed rhoncus elit fermentum ornare. Vestibulum et arcu vitae augue auctor mollis ut nec augue. Praesent facilisis neque et ultrices hendrerit. Sed et orci lacus. Aenean maximus mi elit, accumsan elementum lectus imperdiet id. Nunc ullamcorper dolor at libero aliquet consequat. Cras et varius purus, sit amet vulputate eros. Nullam in lorem dignissim, bibendum sem finibus, cursus risus. Ut ullamcorper varius est id efficitur.
