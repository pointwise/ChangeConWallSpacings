#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

# ----------------------------------------------------------------------------
# This script is intended to help set wall spacing for connectors emanating
# from a set of database surfaces.
# ----------------------------------------------------------------------------

package require PWI_Glyph 2

pw::Script loadTk

# initialize globals
set control(Walls) ""
set control(Connectors,Begin) ""
set control(Connectors,End) ""
set control(Tolerance) "0.0"
set control(CurrentSpacing) "N/A"
set control(Spacing) "0.001"
set control(ModifyDistributions) 1
set control(FromDist) "General"
set control(ToDist) "Tanh"
set control(PreserveSpacings) 0
set control(InitializeDomains) 1
set control(InitializeBlocks) 1
set control(ConnectorsChanged) 1

# widget hierarchy
set w(LabelTitle)                 .title
set w(FrameMain)                  .main
set w(ButtonSelectSurfaces)       $w(FrameMain).bselectsurfaces
set w(LabelTolerance)             $w(FrameMain).ltolerance
set w(EntryTolerance)             $w(FrameMain).etolerance
set w(LabelCurrentSpacing)        $w(FrameMain).lcurrentspacing
set w(LabelCurrentSpacingValue)   $w(FrameMain).lcurrentspacingvalue
set w(LabelNewSpacing)            $w(FrameMain).lnewspacing
set w(EntryNewSpacing)            $w(FrameMain).enewspacing
set w(CheckDistributions)         $w(FrameMain).cdistributions
set w(FrameDistributions)         $w(FrameMain).fdistributions
set w(LabelFromDist)              $w(FrameDistributions).lfromdist
set w(ComboboxFromDist)           $w(FrameDistributions).cfromdist
set w(LabelToDist)                $w(FrameDistributions).ltodist
set w(ComboboxToDist)             $w(FrameDistributions).ctodist
set w(CheckPreserveSpacings)      $w(FrameMain).cpreservespacings
set w(CheckInitializeDomains)     $w(FrameMain).cinitializedomains
set w(CheckInitializeBlocks)      $w(FrameMain).cinitializeblocks
set w(FrameButtons)               .buttons
set w(ButtonOk)                   $w(FrameButtons).bok
set w(ButtonCancel)               $w(FrameButtons).bcancel
set w(ButtonApply)                $w(FrameButtons).bapply
set w(Logo)                       $w(FrameButtons).logo
set w(Message)                    .msg

set color(Valid) SystemWindow
set color(Invalid) MistyRose

# ----------------------------------------------------------------------------
# Check that a database-constrained point is on one of the input surfaces
# or edge curves

proc wallListStrictlyContains { point } {
  global control
  if { [catch { pw::Database getEntity $point } pointDb] } {
    return false
  }

  foreach wall $control(Walls) {
    if [$pointDb equals $wall] {
      return true
    }
  }

  if { [$pointDb isOfType pw::Curve] || [$pointDb isOfType pw::Surface] } {
    # this if statement is necessary, because when a client uses the 
    # "Connectors on Database Entities" tool in Pointwise on a Quilt,
    # the Connectors become connected to the Quilt's edges, rather than the
    # Quilt (unlike other entity types). In addition, the centerpoint on
    # a line on a Quilt will be on the supporting surface rather than the
    # actual quilt
    foreach wall $control(Walls) {
      if [$wall isOfType pw::Quilt] {
        set quilt $wall
        foreach tsurf [$quilt getSupportEntities] {
          # getSupportEntities will return trimmed surfaces,
          # getSupportEntities on the trimmed surfaces will get the curves
          # (which is what the edge connectors are potentially connected
          # to) and the underlying geometric surface
          foreach curve [$tsurf getSupportEntities] {
            if [$pointDb equals $curve] {
              return true
            }
          }
        }
      }
    }
  }

  # if no matches were found, the wall list does not contain the point
  return false
}

# ----------------------------------------------------------------------------
# Check that a cartesian point lies within tolerance of one the input surfaces

proc wallListContainsWithinTolerance { xyz tol } {
  global control
  foreach wall $control(Walls) {
    $wall closestPoint -distance dist $xyz
    if { $dist <= $tol } {
      return true
    }
  }
  return false
}

# ----------------------------------------------------------------------------
# Check that a connector point lies on or near one of the input surfaces

proc wallListContainsConParam { con param tol } {
  if [wallListStrictlyContains [$con getPosition -parameter $param]] {
    return true
  }
  if { $tol > 0.0 } {
    return [wallListContainsWithinTolerance \
        [$con getXYZ -parameter $param] $tol]
  }

  return false
}

# ----------------------------------------------------------------------------
# Find all the connectors that have at least one endpoint on or near one
# of the input surfaces, but do not lie entirely on the surface. Compute
# and set the average spacing value for all wall connectors.

proc findConnectors { {tol ""} } {
  global control
  set averageSpacing "N/A"
  set allTheSame true
  set numSpacings 0
  if { $tol == "" } {
    set tol $control(Tolerance)
  }

  # find all connectors whose begin point is on/near an input surface
  set control(Connectors,Begin) [list]
  foreach con [pw::Grid getAll -type pw::Connector] {
    if { ! [wallListContainsConParam $con 0.5 $tol] &&
           [wallListContainsConParam $con 0.0 $tol] } {
      lappend control(Connectors,Begin) $con
      
      set a [$con getXYZ -grid 1]
      set b [$con getXYZ -grid 2]
      set spacing [pwu::Vector3 length [pwu::Vector3 subtract $a $b]]
      if { $numSpacings == 0 } {
        set averageSpacing $spacing
      } else {
        if { abs($averageSpacing - $spacing) >= .000000001 } {
          set averageSpacing [expr \
            ($averageSpacing*$numSpacings + $spacing) / ($numSpacings + 1)]
          set allTheSame false
        }
      }
      incr numSpacings
    }
  }

  # find all connectors whose end point is on/near an input surface
  set control(Connectors,End) [list]
  foreach con [pw::Grid getAll -type pw::Connector] {
    if { ! [wallListContainsConParam $con 0.5 $tol] &&
           [wallListContainsConParam $con 1.0 $tol] } {
      lappend control(Connectors,End) $con

      set a [$con getXYZ -grid [$con getDimension]]
      set b [$con getXYZ -grid [expr {[$con getDimension] - 1}]]
      set spacing [pwu::Vector3 length [pwu::Vector3 subtract $a $b]]
      if { $numSpacings == 0 } {
        set averageSpacing $spacing
      } else {
        if { abs($averageSpacing - $spacing) >= .000000001 } {
          set averageSpacing [expr {$averageSpacing * $numSpacings / \
              ($numSpacings + 1) + $spacing / ($numSpacings + 1)}]
          set allTheSame false
        }
      }
      incr numSpacings
    }
  }

  if { $numSpacings == 0 } {
    set control(CurrentSpacing) "N/A"
  } else {
    set control(CurrentSpacing) "[format "%12.6g" $averageSpacing]"
  }
  if { ! $allTheSame } {
    append control(CurrentSpacing) " (avg)"
  }
}

# ----------------------------------------------------------------------------
# Test whether a distribution function should be reset.

proc shouldModifyDistribution { dist } {
  global control
  if { $control(ModifyDistributions) } {
    switch $control(FromDist) {
      General {
        return [$dist isOfType pw::DistributionGeneral]
      }
      All {
        return true
      }
    }
  }
  return false
}

# ----------------------------------------------------------------------------
# Apply the input spacing to all the discovered connector ends that emanate
# from the wall surface

proc applySpacing { } {
  global control

  # modify begin spacings
  foreach con $control(Connectors,Begin) {
    if $control(PreserveSpacings) {
      set a [$con getXYZ -grid [$con getDimension]]
      set b [$con getXYZ -grid [expr {[$con getDimension] - 1}]]
      set otherSpacing [pwu::Vector3 length [pwu::Vector3 subtract $a $b]]
    }
    set dist [$con getDistribution 1]
    if [shouldModifyDistribution $dist] {
      if { [string equal $control(ToDist) "Tanh"] } {
        set dist [pw::DistributionTanh create]
      } elseif { [string equal $control(ToDist) "MRQS"] } {
        set dist [pw::DistributionMRQS create]
      }
      $con setDistribution 1 $dist
    }
    $dist setBeginSpacing $control(Spacing)
    if $control(PreserveSpacings) {
      $dist setEndSpacing $otherSpacing
    }
  }

  # modify end spacings
  foreach con $control(Connectors,End) {
    if {$control(PreserveSpacings)} {
      set a [$con getXYZ -grid 1]
      set b [$con getXYZ -grid 2]
      set otherSpacing [pwu::Vector3 length [pwu::Vector3 subtract $a $b]]
    }
    set dist [$con getDistribution [$con getSubConnectorCount]]
    if { [shouldModifyDistribution $dist] } {
      if { [string equal $control(ToDist) "Tanh"] } {
        set dist [pw::DistributionTanh create]
      } elseif { [string equal $control(ToDist) "MRQS"] } {
        set dist [pw::DistributionMRQS create]
      }
      $con setDistribution [$con getSubConnectorCount] $dist
    }
    $dist setEndSpacing $control(Spacing)
    if {$control(PreserveSpacings)} {
      $dist setBeginSpacing $otherSpacing
    }
  }

  # initialize domains
  if $control(InitializeDomains) {
    set connectors [concat $control(Connectors,Begin) $control(Connectors,End)]
    foreach dom [pw::Domain getDomainsFromConnectors $connectors] {
      $dom initialize
    }
  }

  # initialze blocks
  if $control(InitializeBlocks) {
    set connectors "$control(Connectors,Begin) $control(Connectors,End)"
    foreach blk [pw::Block getBlocksFromDomains [pw::Domain \
        getDomainsFromConnectors $connectors]] {
      $blk initialize
    }
  }

  # update spacing in the GUI
  set control(CurrentSpacing) $control(Spacing)

  if $control(ConnectorsChanged) {
    set conGrp [pw::Group create]
    $conGrp setEntityType pw::Connector
    $conGrp addEntity $control(Connectors,Begin)
    $conGrp addEntity $control(Connectors,End)
    set control(ConnectorsChanged) 0
    $conGrp setName "wall-spacing-group"
  }
}

# ----------------------------------------------------------------------------
# Check that an input field is marked valid (normal background color)

proc isEntryValid { widget } {
  global w color
  return [string equal [$w($widget) cget -background] $color(Valid)]
}

# ----------------------------------------------------------------------------
# Update button state (invalidate apply and ok when spacing is not valid)

proc updateButtons { } {
  global w control infoMessage

  if { [llength $control(Walls)] > 0 &&
       [isEntryValid EntryTolerance] &&
       [isEntryValid EntryNewSpacing] } {
    $w(ButtonOk) configure -state normal
    $w(ButtonApply) configure -state normal
    set infoMessage ""
  } else {
    $w(ButtonOk) configure -state disabled
    $w(ButtonApply) configure -state disabled
    if {![isEntryValid EntryTolerance]} {
      set infoMessage "You must give a positive, or zero float value for the\
          tolerance."
    } elseif {![isEntryValid EntryNewSpacing]} {
      set infoMessage "You must give a positive, nonzero, float value spacing."
    } else {
      set infoMessage "You must select at least one database to alter. Click\
          the Select Wall Database Surfaces button."
    }
  }
}

# ----------------------------------------------------------------------------
# Check that the tolerance input is valid

proc validateTolerance { u widget } {
  global color control
  if { [llength $u] == 1 && \
      [string is double -strict $u] && \
      $u >= 0 } {
    $widget configure -background $color(Valid)
    unsetSelectionColors
    findConnectors $u
    setSelectionColors
  } else {
    $widget configure -background $color(Invalid)
  }
  updateButtons
  set control(ConnectorsChanged) 1
  return true
}

# ----------------------------------------------------------------------------
# Check that the spacing input is valid

proc validateSpacing { u widget } {
  global color
  if { [llength $u] == 1 && [string is double -strict $u] && $u > 0 } {
    $widget configure -background $color(Valid)
  } else {
    $widget configure -background $color(Invalid)
  }
  updateButtons
  return true
}

# ----------------------------------------------------------------------------
# Clear temporary surface selection color

proc unsetSelectionColors { } {
  global control color colorMode lineWidth
  foreach db $control(Walls) {
    $db setColor $color($db)
    $db setRenderAttribute ColorMode $colorMode($db)
  }
  foreach con [concat $control(Connectors,Begin) $control(Connectors,End)] {
    $con setColor $color($con)
    $con setRenderAttribute ColorMode $colorMode($con)
    $con setRenderAttribute LineWidth $lineWidth($con)
  }
  pw::Display update
}

# ----------------------------------------------------------------------------
# Set color of selected surfaces temporarily

proc setSelectionColors { } {
  global control color colorMode lineWidth
  foreach db $control(Walls) {
    set color($db) [$db getColor]
    set colorMode($db) [$db getRenderAttribute ColorMode]
    $db setColor 0x00ffffff
    $db setRenderAttribute ColorMode Entity
  }
  foreach con [concat $control(Connectors,Begin) $control(Connectors,End)] {
    if { ! [info exists color($con)] } {
      # only save if color not set. Especially important when a connector's
      # beginning and end spacing are both being changed, because the connector
      # will appear twice in the foreach list, and without this check, the
      # second time the attributes will get set to the selection color/style
      set color($con) [$con getColor]
      set colorMode($con) [$con getRenderAttribute ColorMode]
      set lineWidth($con) [$con getRenderAttribute LineWidth]
    }
    $con setColor 0x00ffffff
    $con setRenderAttribute ColorMode Entity
    $con setRenderAttribute LineWidth 3
  }
  pw::Display update
}

# ----------------------------------------------------------------------------
# Update widget state for distribution modification checkbox

proc checkDistCommand { } {
  global w control
  if { $control(ModifyDistributions) } {
    $w(LabelFromDist) configure -state normal
    $w(ComboboxFromDist) configure -state readonly
    $w(LabelToDist) configure -state normal
    $w(ComboboxToDist) configure -state readonly
  } else {
    $w(LabelFromDist) configure -state disabled
    $w(ComboboxFromDist) configure -state disabled
    $w(LabelToDist) configure -state disabled
    $w(ComboboxToDist) configure -state disabled
  }
  updateButtons
}

# ----------------------------------------------------------------------------
# Database selection

proc chooseDbEntities { } {
  global control
  set mask [pw::Display createSelectionMask -requireDatabase [list] \
      -blockDatabase [list Models Planes Points]]
  pw::Display selectEntities -description "Select a database\
      surfaces from which wall spacing is to be set." \
      -selectionmask $mask -preselect $control(Walls) selection
  return [lsort $selection(Databases)]
}

# ----------------------------------------------------------------------------
# Compare two entity lists for equivalency. It is assumed that both lists are
# sorted.

proc compareLists { a b } {
  if { [llength $a] == [llength $b] } {
    foreach i $a j $b {
      if { ! [$i equals $j] } {
        return false
      }
    }
    return true
  }
  return false
}

# ----------------------------------------------------------------------------
# Start database selection and update GUI based on new selection

proc wallSelectAction { } {
  global control
  unsetSelectionColors
  wm state . withdrawn
  set walls [chooseDbEntities]
  if { [llength $walls] > 0 && ! [compareLists $walls $control(Walls)] } {
    set control(ConnectorsChanged) 1
    set control(Walls) $walls
  }
  wm state . normal
  raise .
  findConnectors
  setSelectionColors
  updateButtons
}

# ----------------------------------------------------------------------------
# Handle OK button press (same as Apply, then Cancel)

proc okAction { } {
  applyAction
  cancelAction
}

# ----------------------------------------------------------------------------
# Handle Cancel button press by clearing temporary selection colors

proc cancelAction { } {
  unsetSelectionColors
  exit
}

# ----------------------------------------------------------------------------
# Handle Apply button press by setting wall spacing for discovered connector
# ends

proc applyAction { } {
  global w
  applySpacing
  pw::Display update
}

# ----------------------------------------------------------------------------
# set the font for the input widget to be bold and 1.5 times larger than
# the default font

proc setTitleFont { l } {
  global titleFont
  if { ! [info exists titleFont] } {
    set fontSize [font actual TkCaptionFont -size]
    set titleFont [font create -family [font actual TkCaptionFont -family] \
        -weight bold -size [expr {int(1.5 * $fontSize)}]]
  }
  $l configure -font $titleFont
}

# ----------------------------------------------------------------------------
# Create the GUI

proc makeWindow { } {
  global w control infoMessage

  # create the widgets
  label $w(LabelTitle) -text "Wall Spacing Adjustment Utility"
  setTitleFont $w(LabelTitle)
  wm title . "Wall Spacing Adjustment Utility"

  frame $w(FrameMain)

  button $w(ButtonSelectSurfaces) -width 36 -bd 2 -command wallSelectAction \
      -text "Select Wall Database Surfaces"

  label $w(LabelTolerance) -text "Tolerance:" -padx 2 -anchor e
  entry $w(EntryTolerance) -width 6 -bd 2 -textvariable control(Tolerance)

  label $w(LabelCurrentSpacing) -text "Current Spacing:" -padx 2 -anchor e
  label $w(LabelCurrentSpacingValue) -textvariable control(CurrentSpacing) \
      -padx 2 -anchor w -width 18
  
  label $w(LabelNewSpacing) -text "New Spacing:" -padx 2 -anchor e
  entry $w(EntryNewSpacing) -width 6 -bd 2 -textvariable control(Spacing)

  checkbutton $w(CheckDistributions) -text "Modify Distributions" -padx 2 \
      -anchor w -variable control(ModifyDistributions) \
      -command checkDistCommand
  labelframe $w(FrameDistributions) -labelwidget $w(CheckDistributions) \
      -relief groove -bd 3

  label $w(LabelFromDist) -text "Change "
  ttk::combobox $w(ComboboxFromDist) -textvariable control(FromDist) \
      -values "General All" -width 8 -state readonly \
      -postcommand updateButtons
  label $w(LabelToDist) -text " distributions to "
  ttk::combobox $w(ComboboxToDist) -textvariable control(ToDist) \
      -values "Tanh MRQS" -width 8 -state readonly \
      -postcommand updateButtons

  checkbutton $w(CheckPreserveSpacings) \
      -text "Preserve automatic spacing constraints" -padx 2 \
      -variable control(PreserveSpacings) -anchor w -command updateButtons

  checkbutton $w(CheckInitializeDomains) \
      -text "Initialize affected domains" -padx 2 \
      -variable control(InitializeDomains) -anchor w -command updateButtons

  checkbutton $w(CheckInitializeBlocks) \
      -text "Initialize affected blocks" -padx 2 \
      -variable control(InitializeBlocks) -anchor w -command updateButtons

  frame $w(FrameButtons) -bd 1 -relief sunken
    
  button $w(ButtonOk) -width 6 -bd 2 -text "OK" -command okAction
  button $w(ButtonCancel) -width 6 -bd 2 -text "Cancel" -command cancelAction
  button $w(ButtonApply) -width 6 -bd 2 -text "Apply" -command applyAction
    
  label $w(Logo) -image [cadenceLogo] -bd 0 -relief flat
  message $w(Message) -textvariable infoMessage -background beige \
                      -bd 2 -relief sunken -padx 5 -pady 5 -anchor w \
                      -justify left -width 300

  # validation
  $w(EntryTolerance) configure -validate key -vcmd { validateTolerance %P %W }
  $w(EntryNewSpacing) configure -validate key -vcmd { validateSpacing %P %W }

  # lay out the toplevel window
  pack $w(LabelTitle) -side top
  pack [frame .sp -bd 1 -height 2 -relief sunken] -pady 4 -side top -fill x
  pack $w(FrameMain) -side top -fill x
  pack $w(Message) -side bottom -fill x -anchor s
  pack $w(FrameButtons) -side bottom -fill x -expand 1

  # lay out the input form
  grid $w(ButtonSelectSurfaces) -sticky ew -pady 3 -padx 15 -columnspan 2
  grid $w(LabelTolerance) $w(EntryTolerance) -sticky ew -pady 3 -padx 3
  grid $w(LabelCurrentSpacing) $w(LabelCurrentSpacingValue) -sticky ew -pady 3 \
      -padx 3
  grid $w(LabelNewSpacing) $w(EntryNewSpacing) -sticky ew -pady 3 -padx 3
  grid $w(FrameDistributions) -sticky ew -pady 3 -padx 3 -columnspan 2
  grid $w(LabelFromDist) $w(ComboboxFromDist) $w(LabelToDist) \
       $w(ComboboxToDist) -sticky w -pady 3 -padx 3
  grid $w(CheckPreserveSpacings) -sticky ew -pady 3 -padx 3 -columnspan 2
  grid $w(CheckInitializeDomains) -sticky ew -pady 3 -padx 3 -columnspan 2
  grid $w(CheckInitializeBlocks) -sticky ew -pady 3 -padx 3 -columnspan 2

  # lay out the buttons
  pack $w(ButtonApply) $w(ButtonCancel) $w(ButtonOk) -pady 3 -padx 3 -side right
  pack $w(Logo) -side left -padx 5

  # default key bindings
  bind . <Control-Return> { $w(ButtonOk) invoke }
  bind . <Escape> { $w(ButtonCancel) invoke }

  # make sure colors are returned back to their normal state when user exits
  # by pressing the X button
  wm protocol . WM_DELETE_WINDOW cancelAction
    
  updateButtons

  # move keyboard focus to first item
  focus $w(ButtonSelectSurfaces)
  raise .

  # don't allow window to resize
  wm resizable . 0 0
}

# ----------------------------------------------------------------------------
# Return the Cadence Design Systems logo image

proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}

makeWindow

tkwait window .
  
#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
