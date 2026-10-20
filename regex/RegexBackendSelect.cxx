// RegexBackendSelect.cxx
//
// Single SCI_OWNREGEX factory that selects, at Document-regex creation time,
// between two fully independent RegexSearchBase backends:
//
//   * NppRegexSearch  (default) — the per-line std::regex engine. Unchanged;
//                                 this is the path used when the preference is off.
//   * BoostRegexSearch (opt-in) — the whole-buffer Boost.Regex engine, giving
//                                 Windows parity (multi-line matches, lookbehind,
//                                 \K, etc.).
//
// The choice is driven by the "Use Boost Regex mode" Searching preference, which
// PreferencesWindowController mirrors into gNppUseBoostRegex. Scintilla creates a
// Document's regex object lazily and caches it, so a toggle takes effect for
// Documents whose first regex search happens afterwards (i.e. "switch then
// restart" for already-searched documents) — by design, keeping the two paths
// strictly separate with no shared state.

// Document.h pulls in the usual Scintilla type prerequisites; include the same
// preamble the backend .cxx files use so RegexSearchBase/CharClassify resolve.
#include <cstddef>
#include <string_view>
#include <vector>
#include <memory>
#include <map>
#include <optional>

#include "ScintillaTypes.h"
#include "ScintillaMessages.h"
#include "Debugging.h"
#include "Geometry.h"
#include "Platform.h"
#include "ILoader.h"
#include "ILexer.h"
#include "Position.h"
#include "SplitVector.h"
#include "Partitioning.h"
#include "RunStyles.h"
#include "CharacterCategoryMap.h"
#include "CellBuffer.h"
#include "CharClassify.h"
#include "Decoration.h"
#include "CaseFolder.h"
#include "Document.h"

// Plain C-linkage symbol so the ObjC++ Preferences code can set it directly.
extern "C" { bool gNppUseBoostRegex = false; }

namespace Scintilla::Internal {

extern RegexSearchBase *CreateNppRegexSearch(CharClassify *charClassTable);
extern RegexSearchBase *CreateBoostRegexSearch(CharClassify *charClassTable);

#ifdef SCI_OWNREGEX
RegexSearchBase *CreateRegexSearch(CharClassify *charClassTable) {
    return gNppUseBoostRegex
        ? CreateBoostRegexSearch(charClassTable)
        : CreateNppRegexSearch(charClassTable);
}
#endif

} // namespace Scintilla::Internal
