import { useCallback, useRef, useState } from 'react';

import { useIntl, defineMessages } from 'react-intl';

import classNames from 'classnames';

import { Popover } from '@/mastodon/components/popover';
import TagIcon from '@/material-icons/400-24px/tag.svg?react';
import { Icon } from 'mastodon/components/icon';
import { featuredTags } from 'mastodon/initial_state';

const messages = defineMessages({
  add_tag: {
    id: 'status.featured_tags.add',
    defaultMessage: 'Add your featured tag',
  },
});

const FeaturedTagDropdownMenu: React.FC<{
  items: string[];
  onClose: () => void;
  onChange: (arg0: string) => void;
}> = ({ items, onClose, onChange }) => {
  const tags = items;
  const nodeRef = useRef<HTMLDivElement>(null);
  const listNodeRef = useRef<HTMLDivElement>(null);

  const handleClick = useCallback(
    (e: React.MouseEvent | React.KeyboardEvent) => {
      const value = e.currentTarget.getAttribute('data-index');

      if (!value) {
        return;
      }

      e.preventDefault();

      onClose();
      onChange(value);
    },
    [onClose, onChange, items],
  );

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (!listNodeRef.current) {
        return;
      }

      const index = Array.from(listNodeRef.current.childNodes).findIndex(
        (node) => node === e.currentTarget,
      );

      let element = null;

      switch (e.key) {
        case 'Escape':
          onClose();
          break;
        case ' ':
        case 'Enter':
          handleClick(e);
          break;
        case 'ArrowDown':
          element =
            listNodeRef.current.childNodes[index + 1] ??
            listNodeRef.current.firstChild;
          break;
        case 'ArrowUp':
          element =
            listNodeRef.current.childNodes[index - 1] ??
            listNodeRef.current.lastChild;
          break;
        case 'Tab':
          if (e.shiftKey) {
            element =
              listNodeRef.current.childNodes[index - 1] ??
              listNodeRef.current.lastChild;
          } else {
            element =
              listNodeRef.current.childNodes[index + 1] ??
              listNodeRef.current.firstChild;
          }
          break;
        case 'Home':
          element = listNodeRef.current.firstChild;
          break;
        case 'End':
          element = listNodeRef.current.lastChild;
          break;
      }

      if (element && element instanceof HTMLElement) {
        element.focus();
        e.preventDefault();
        e.stopPropagation();
      }
    },
    [onClose, handleClick],
  );

  return (
    <div ref={nodeRef}>
      <div
        className='language-dropdown__dropdown__results emoji-mart-scroll'
        role='listbox'
        ref={listNodeRef}
      >
        {tags.map((tag) => (
          <div
            key={tag}
            role='option'
            tabIndex={0}
            data-index={tag}
            className={classNames('language-dropdown__dropdown__results__item')}
            aria-selected={false}
            onClick={handleClick}
            onKeyDown={handleKeyDown}
          >
            <span className='language-dropdown__dropdown__results__item__native-name'>
              #{tag}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

export const FeaturedTagDropdown: React.FC<{
  onPickTag: (tag: string) => void;
}> = ({ onPickTag }) => {
  const [open, setOpen] = useState(false);
  const activeElementRef = useRef<HTMLElement | null>(null);
  const [targetElement, setTargetElement] = useState<HTMLElement | null>(null);

  const intl = useIntl();

  const tags = featuredTags;
  const unavailable = tags.length === 0;

  const handleMouseDown = useCallback(() => {
    if (!open && document.activeElement instanceof HTMLElement) {
      activeElementRef.current = document.activeElement;
    }
  }, [open]);

  const handleToggle = useCallback(() => {
    if (open && activeElementRef.current)
      activeElementRef.current.focus({ preventScroll: true });

    setOpen(!open);
  }, [open, setOpen]);

  const handleClose = useCallback(() => {
    if (open && activeElementRef.current)
      activeElementRef.current.focus({ preventScroll: true });

    setOpen(false);
  }, [open, setOpen]);

  const handleChange = useCallback(
    (value: string) => {
      onPickTag(`#${value}`);
    },
    [onPickTag],
  );

  if (unavailable) return null;

  return (
    <>
      <button
        type='button'
        ref={setTargetElement}
        title={intl.formatMessage(messages.add_tag)}
        aria-expanded={open}
        onClick={handleToggle}
        onMouseDown={handleMouseDown}
        className={classNames('dropdown-button', {
          active: open,
        })}
      >
        <Icon id='clock-o' icon={TagIcon} />
      </button>

      <Popover
        isOpen={open}
        onClose={handleClose}
        offset={5}
        reference={targetElement}
      >
        {({ props, placement }) => (
          <div {...props}>
            <div
              className={`dropdown-animation language-dropdown__dropdown ${placement}`}
            >
              <FeaturedTagDropdownMenu
                items={tags}
                onClose={handleClose}
                onChange={handleChange}
              />
            </div>
          </div>
        )}
      </Popover>
    </>
  );
};
