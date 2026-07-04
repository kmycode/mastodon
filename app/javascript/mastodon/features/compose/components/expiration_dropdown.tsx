import { useCallback, useRef, useState } from 'react';

import { useIntl, defineMessages } from 'react-intl';

import classNames from 'classnames';

import { Popover } from '@/mastodon/components/popover';
import TimerIcon from '@/material-icons/400-24px/timer.svg?react';
import { Icon } from 'mastodon/components/icon';

const messages = defineMessages({
  add_expiration: {
    id: 'status.expiration.add',
    defaultMessage: 'Set status expiration',
  },
  expiration_5_minutes: {
    id: 'status.expiration.5_minutes',
    defaultMessage: 'Remove 5 minutes later',
  },
  expiration_30_minutes: {
    id: 'status.expiration.30_minutes',
    defaultMessage: 'Remove 30 minutes later',
  },
  expiration_1_hour: {
    id: 'status.expiration.1_hour',
    defaultMessage: 'Remove 1 hour later',
  },
  expiration_3_hours: {
    id: 'status.expiration.3_hours',
    defaultMessage: 'Remove 3 hours later',
  },
  expiration_12_hours: {
    id: 'status.expiration.12_hours',
    defaultMessage: 'Remove 12 hours later',
  },
  expiration_1_day: {
    id: 'status.expiration.1_day',
    defaultMessage: 'Remove 1 day later',
  },
  expiration_7_days: {
    id: 'status.expiration.7_days',
    defaultMessage: 'Remove 7 days later',
  },
});

interface ExpirationItem {
  value: string;
  text: string;
}

const ExpirationDropdownMenu: React.FC<{
  items: ExpirationItem[];
  onClose: () => void;
  onChange: (arg0: ExpirationItem) => void;
}> = ({ items, onClose, onChange }) => {
  const tags = items;
  const nodeRef = useRef<HTMLDivElement>(null);
  const listNodeRef = useRef<HTMLDivElement>(null);

  const handleClick = useCallback(
    (e: React.MouseEvent | React.KeyboardEvent) => {
      const valueIndex = e.currentTarget.getAttribute('data-index');
      const value = items.find((item) => item.value === valueIndex);

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
            key={tag.value}
            role='option'
            tabIndex={0}
            data-index={tag.value}
            className={classNames('language-dropdown__dropdown__results__item')}
            aria-selected={false}
            onClick={handleClick}
            onKeyDown={handleKeyDown}
          >
            <span className='language-dropdown__dropdown__results__item__native-name'>
              {tag.text}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

export const ExpirationDropdown: React.FC<{
  onPickExpiration: (tag: string) => void;
}> = ({ onPickExpiration }) => {
  const [open, setOpen] = useState(false);
  const activeElementRef = useRef<HTMLElement | null>(null);
  const [targetElement, setTargetElement] = useState<HTMLElement | null>(null);

  const intl = useIntl();

  const tags = [
    {
      value: '#exp5m',
      text: intl.formatMessage(messages.expiration_5_minutes),
    },
    {
      value: '#exp30m',
      text: intl.formatMessage(messages.expiration_30_minutes),
    },
    { value: '#exp1h', text: intl.formatMessage(messages.expiration_1_hour) },
    { value: '#exp3h', text: intl.formatMessage(messages.expiration_3_hours) },
    {
      value: '#exp12h',
      text: intl.formatMessage(messages.expiration_12_hours),
    },
    { value: '#exp1d', text: intl.formatMessage(messages.expiration_1_day) },
    { value: '#exp7d', text: intl.formatMessage(messages.expiration_7_days) },
  ] satisfies ExpirationItem[];
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
    (value: ExpirationItem) => {
      onPickExpiration(value.value);
    },
    [onPickExpiration],
  );

  if (unavailable) return null;

  return (
    <>
      <button
        type='button'
        ref={setTargetElement}
        title={intl.formatMessage(messages.add_expiration)}
        aria-expanded={open}
        onClick={handleToggle}
        onMouseDown={handleMouseDown}
        className={classNames('dropdown-button', {
          active: open,
        })}
      >
        <Icon id='clock-o' icon={TimerIcon} />
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
              <ExpirationDropdownMenu
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
